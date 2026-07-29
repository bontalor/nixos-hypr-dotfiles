// Clipboard history state. Two shell-owned `wl-paste --watch` processes
// feed an in-QML MRU list, persisted via FileView+JsonAdapter in the
// state dir. No cliphist, no compositor-side autostart — the watchers
// live and die with the shell, and only run while the Settings
// "Clipboard history" pref is on (existing history is kept when off).
//
//   - text watcher: streams selections NUL-framed so multiline entries
//     survive; standalone "<img src=...>" HTML is skipped (the image
//     watcher captures the actual image from the same offer).
//   - image watcher: image-only offers (screenshots, image copies)
//     are written to imageDir under a content-hash name — identical
//     images land on the same path, so the normal string dedupe gives
//     image dedupe/MRU for free — and stored as a file:// entry, which
//     the panel already thumbnails and copyImage() already re-copies.
//
// Quickshell.clipboardText is NOT usable for this: in 0.3.0 it neither
// sees external clipboard changes nor reliably owns a real selection
// (verified empirically) — hence wl-paste/wl-copy, which were already
// dependencies.
//
// Note: history is plaintext on disk (same trade-off as cliphist's db);
// clear() wipes it.

pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../notifications"
import "../util"

Singleton {
    id: root

    property int historyMax: 100
    property int imageRowHeight: 80   // thumbnail rows in the panel
    // Image copies above this size aren't kept in history (5 MB,
    // matching cliphist's default).
    property int imageMaxBytes: 5242880
    // Per-entry character cap — larger copies are not recorded (the
    // whole history rewrites to disk on every change).
    property int entryMaxLength: 100000

    // Newest first. Assigning a fresh array persists via onAdapterUpdated.
    readonly property var entries: adapter.entries

    readonly property string imageDir: Paths.stateDir + "/clipboard-images"

    function push(text) {
        if (text === "" || text.trim() === "") return
        // Oversized copies (accidental huge-file pastes) would bloat the
        // JSON store, which is rewritten on every change. Surface this
        // as a notification so the "I copied that — where is it?" gap
        // doesn't go invisible (matches the image-watcher's oversize notify).
        if (text.length > root.entryMaxLength) {
            NotifDaemon.notify("Clipboard text not kept",
                Math.round(text.length / 1000) + "k chars exceeds the "
                + Math.round(root.entryMaxLength / 1000)
                + "k limit (ClipboardModel.entryMaxLength)",
                NotificationUrgency.Normal)
            return
        }
        // Short-circuit re-copies of whatever's already at the front:
        // every re-copy rewrites the whole JSON file (atomicWrites), so
        // filtering the common case — re-selecting the same text —
        // is a free disk-write savings on the most-frequent path.
        if (adapter.entries.length > 0 && adapter.entries[0] === text) return
        var out = [text]
        for (var i = 0; i < adapter.entries.length; i++) {
            if (adapter.entries[i] !== text) out.push(adapter.entries[i])
        }
        var dropped = out.slice(root.historyMax)
        adapter.entries = out.slice(0, root.historyMax)
        root.deleteImageFiles(dropped)
    }

    // Delete the backing files of evicted image entries so imageDir
    // doesn't grow past the history cap. Silent — a missing file is fine.
    // Evictions are queued (rmQueue) and drained by rmProc.onExited so a
    // flood of pushes (rapidly copying different images) can't drop
    // commands by reassigning `rmProc.command` while the previous rm is
    // still running. The previous single-shared-Process pattern leaked
    // image files in imageDir under burst.
    function deleteImageFiles(list) {
        var files = []
        for (var i = 0; i < list.length; i++) {
            if (list[i].startsWith("file://" + root.imageDir + "/"))
                files.push(list[i].slice(7))
        }
        if (files.length === 0) return
        rmQueue = rmQueue.concat(files)
        root.drainRmQueue()
    }

    function drainRmQueue() {
        if (rmProc.running || rmQueue.length === 0) return
        rmProc.command = ["rm", "-f"].concat(rmQueue)
        rmQueue = []
        rmProc.running = true
    }

    property var rmQueue: []

    // Copying re-triggers the watcher, which push()es the entry back to
    // the front — the MRU reorder falls out for free.
    function copy(text) {
        copyProc.command = ["wl-copy", text]
        copyProc.running = true
    }

    // Put actual image bytes on the clipboard for an image entry, so
    // pasting yields the image, not its "<img src=...>" text. wl-copy
    // sniffs the MIME type from the data (xdg-mime), so no type mapping
    // is needed. Remote URLs go through curl — if the link has expired
    // (e.g. signed CDN URLs), the pipefail surfaces it as a
    // notification instead of silently copying nothing.
    //
    // Requests are queued (imgQueue) and drained by imgProc.onExited so
    // two adjacent `copyImage` calls (rapid Enter in the panel) don't both
    // write to one shared Process and lose the first request mid-flight.
    function copyImage(src) {
        var cmd
        if (src.startsWith("file://")) {
            cmd = ["bash", "-c", 'set -o pipefail; wl-copy < "$1"',
                   "bash", decodeURIComponent(src.slice(7))]
        } else if (src.startsWith("data:")) {
            var comma = src.indexOf(",")
            var meta = src.slice(5, comma)
            var payload = src.slice(comma + 1)
            cmd = meta.endsWith(";base64")
                ? ["bash", "-c", 'set -o pipefail; printf %s "$1" | base64 -d | wl-copy', "bash", payload]
                : ["bash", "-c", 'set -o pipefail; printf %s "$1" | wl-copy', "bash", decodeURIComponent(payload)]
        } else {
            cmd = ["bash", "-c",
                'set -o pipefail; curl -sfL --max-time 15 "$1" | wl-copy', "bash", src]
        }
        imgQueue.push(cmd)
        root.drainImgQueue()
    }

    function drainImgQueue() {
        if (imgProc.running || imgQueue.length === 0) return
        imgProc.command = imgQueue.shift()
        imgProc.running = true
    }

    property var imgQueue: []

    function clear() {
        root.deleteImageFiles(adapter.entries)
        adapter.entries = []
    }

    // Watchers run only while the Settings pref is on. A Process breaks
    // its `running` binding when it exits by itself, so the pref toggle
    // and the respawn timers re-apply the value imperatively below.
    Connections {
        target: PrefStore
        function onClipboardHistoryChanged() {
            watcher.running = PrefStore.clipboardHistory
            imageWatcher.running = PrefStore.clipboardHistory
        }
    }

    Process {
        id: watcher
        running: PrefStore.clipboardHistory
        // The watch command receives each new selection on stdin; `cat`
        // passes it through with a NUL terminator so the SplitParser can
        // frame entries (clipboard text can contain anything but NUL).
        // Only CLIPBOARD_STATE=data is forwarded: `sensitive` marks
        // password-manager copies (x-kde-passwordManagerHint — respected
        // here, unlike cliphist), and `nil`/`clear` carry no data.
        command: ["wl-paste", "--type", "text", "--watch", "sh", "-c",
                  "[ \"$CLIPBOARD_STATE\" = data ] || exit 0; cat; printf '\\0'"]
        stdout: SplitParser {
            splitMarker: "\0"
            // Standalone <img> HTML is the text side of a browser image
            // copy — the image watcher stores the real image instead.
            onRead: text => { if (!/^\s*<img\s/i.test(text)) root.push(text) }
        }
        // Respawn if wl-paste ever dies (compositor restart of the
        // data-control connection, etc.).
        onExited: respawn.restart()
    }

    Process {
        id: imageWatcher
        running: PrefStore.clipboardHistory
        // Image-only offers (screenshots, copied images) have no text
        // type, so the text watcher never sees them. This one writes
        // the bytes to imageDir named by bare content hash — no
        // extension, since wl-paste may deliver any image format and a
        // guessed suffix would lie; everything downstream (Image
        // thumbnails, wl-copy) sniffs content, and the panel classifies
        // these entries by their imageDir location. Oversized images
        // are dropped (imageMaxBytes).
        command: ["wl-paste", "--type", "image", "--watch", "sh", "-c",
                  '[ "$CLIPBOARD_STATE" = data ] || exit 0; ' +
                  'mkdir -p "$1"; ' +
                  't=$(mktemp "$1/.tmp-XXXXXX") || exit 0; ' +
                  'cat > "$t"; ' +
                  's=$(stat -c%s "$t"); ' +
                  'if [ "$s" -gt ' + root.imageMaxBytes + ' ]; then rm -f "$t"; printf "oversize:%s\\0" "$s"; exit 0; fi; ' +
                  'h=$(sha256sum "$t" | cut -c1-16); ' +
                  'f="$1/$h"; mv "$t" "$f"; ' +
                  'printf "file://%s\\0" "$f"',
                  "sh", root.imageDir]
        stdout: SplitParser {
            splitMarker: "\0"
            onRead: msg => {
                // A dropped-for-size copy is reported, not silently
                // ignored — an invisible "I copied that, where is it?"
                // gap is worse than the popup.
                if (msg.startsWith("oversize:"))
                    NotifDaemon.notify("Clipboard image not kept",
                        Math.round(parseInt(msg.slice(9)) / 1048576) + " MB exceeds the "
                        + Math.round(root.imageMaxBytes / 1048576)
                        + " MB history limit (ClipboardModel.imageMaxBytes)",
                        NotificationUrgency.Normal)
                else root.push(msg)
            }
        }
        onExited: imageRespawn.restart()
    }

    Timer {
        id: respawn
        interval: 1000
        onTriggered: watcher.running = PrefStore.clipboardHistory
    }

    Timer {
        id: imageRespawn
        interval: 1000
        onTriggered: imageWatcher.running = PrefStore.clipboardHistory
    }

    // `rm -f` for eviction; clears `rmProc.running` and drains the next
    // queued batch (see deleteImageFiles).
    Process {
        id: rmProc
        running: false
        onExited: root.drainRmQueue()
    }

    // Self-heal: drop history entries whose backing image file is gone
    // (deleted out-of-band, or orphaned by an old eviction bug). Without
    // this, every dead entry logs a thumbnail "Cannot open" warning on
    // each panel open, forever. Run lazily on the first panel open, not
    // at singleton startup — running at startup races fresh wl-paste
    // pushes that land between prune's for-loop and the
    // `adapter.entries = out` assignment, silently discarding the
    // just-pushed entry.
    property bool _pruned: false
    function pruneIfNeeded() {
        if (root._pruned) return
        root._pruned = true
        pruneProc.command = ["sh", "-c", 'ls -- "$1" 2>/dev/null || true', "sh", imageDir]
        pruneProc.running = true
    }
    Process {
        id: pruneProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.pruneMissingImages(text)
        }
    }

    function pruneMissingImages(lsText) {
        var prefix = "file://" + root.imageDir + "/"
        var existing = {}
        var names = lsText.split("\n")
        for (var i = 0; i < names.length; i++) {
            if (names[i] !== "") existing[prefix + names[i]] = true
        }
        // Snapshot once. Iterating the live `adapter.entries` while a
        // wl-paste packet lands and reassigns it mid-loop led to entries
        // being dropped from `out` despite existing seconds earlier.
        var snapshot = adapter.entries.slice()
        var out = []
        for (var j = 0; j < snapshot.length; j++) {
            var e = snapshot[j]
            if (!e.startsWith(prefix) || existing[e]) out.push(e)
        }
        if (out.length !== snapshot.length) adapter.entries = out
    }

    CheckedProcess {
        id: copyProc
        label: "wl-copy"
        running: false
    }

    // `wl-copy` for image entries; drains the next queued request on exit.
    CheckedProcess {
        id: imgProc
        label: "image copy"
        running: false
        onQueueFinished: root.drainImgQueue()
    }

    FileView {
        path: Paths.stateDir + "/clipboard.json"
        blockLoading: true
        atomicWrites: true
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter
            property list<string> entries: []
        }
    }
}
