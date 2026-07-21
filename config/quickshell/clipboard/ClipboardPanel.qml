// Clipboard history — backed by ClipboardModel (shell-owned wl-paste
// watcher + persisted MRU list; see the model for the design notes).
// Enter or click copies the entry back to the clipboard; the search
// matches anywhere in the full text, not just the preview line.

pragma ComponentBehavior: Bound

import "../theme"
import "../components"
import "../util"
import "."
import QtQuick
import Quickshell

SearchPanel {
    id: root
    title: "Clipboard"

    // Trigger lazy self-heal on first open (see ClipboardModel.pruneIfNeeded):
    // runs `ls imageDir` once to evict history entries whose backing file
    // is gone, avoiding per-open "Cannot open" thumbnail warnings. Run
    // here rather than at singleton startup so the snapshot can't race
    // a fresh wl-paste push.
    onVisibleChanged: if (visible) ClipboardModel.pruneIfNeeded()

    // One row per history entry: `text` is the exact clipboard content,
    // `name` a single-line preview (whitespace runs collapsed). A
    // synthetic "Clear All" row is pinned first whenever the history is
    // non-empty; matchPredicate excludes it from searches so a query's
    // first result (auto-selected — Enter fires it) is never the
    // destructive clear.
    items: {
        var out = []
        var es = ClipboardModel.entries
        if (es.length > 0) out.push({ clearAll: true, name: "Clear All", text: "" })
        for (var i = 0; i < es.length; i++) {
            out.push({ text: es[i], name: es[i].replace(/\s+/g, " ").trim() })
        }
        return out
    }

    matchPredicate: function(item, q) {
        return !item.clearAll && item.text.toLowerCase().includes(q)
    }

    emptyText: ClipboardModel.entries.length === 0
        ? (PrefStore.clipboardHistory
           ? "Clipboard history is empty"
           : "Clipboard history is off (Settings → Clipboard)")
        : "No matches"

    // Entries that are really images: browser image copies arrive as
    // "<img src=...>" HTML (which Text.AutoText would otherwise render
    // full-size), plus file:// and data: image URIs. Our own captures
    // (files in ClipboardModel.imageDir) are classified by location —
    // they're named by bare content hash, so there's no extension to
    // match. Returns the source URL for the thumbnail, or "" for plain
    // text.
    function imageSource(text) {
        var t = text.trim()
        var m = t.match(/^<img[^>]+src=["']([^"']+)["']/i)
        if (m) return m[1]
        if (t.startsWith("file://" + ClipboardModel.imageDir + "/")) return t
        if (/^file:\/\/\S+\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(t)) return t
        if (/^data:image\//i.test(t)) return t
        return ""
    }

    onLaunched: function(idx) {
        var e = root.filtered[idx]
        if (!e) return
        if (e.clearAll) {
            // Keep the panel open — the empty-state label is the feedback.
            ClipboardModel.clear()
            return
        }
        var img = root.imageSource(e.text)
        if (img) ClipboardModel.copyImage(img)
        else ClipboardModel.copy(e.text)
        root.visible = false
    }

    rowDelegate: SearchRow {
        id: row
        readonly property string imgSrc: root.imageSource(modelData?.text ?? "")

        // Image rows grow (with their highlight background) to fit the
        // thumbnail; SearchPanel scrolls by real geometry, so mixed
        // heights are fine.
        height: imgSrc !== "" ? ClipboardModel.imageRowHeight : Theme.searchRowHeight

        Image {
            id: thumb
            visible: row.imgSrc !== ""
            source: row.imgSrc
            anchors.verticalCenter: parent.verticalCenter
            height: ClipboardModel.imageRowHeight - Theme.margin
            // Follow the image's aspect ratio once loaded, capped so
            // wide screenshots don't span the whole panel.
            width: Math.min(
                status === Image.Ready && implicitHeight > 0
                    ? height * implicitWidth / implicitHeight : height,
                Theme.panelWidth / 2)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize.height: 2 * ClipboardModel.imageRowHeight
        }

        ThemeText {
            visible: row.imgSrc !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: row.imgSrc
            color: Qt.alpha(Colors.foreground, Theme.alphaDim)
            size: "small"
            // Fill the rest of the row: total width minus the thumbnail,
            // the content Row's left margin + spacing, and right padding.
            width: row.width - thumb.width - 3 * Theme.margin
            elide: Text.ElideMiddle
        }

        ThemeText {
            visible: row.imgSrc === ""
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData?.name ?? ""
            // The pinned Clear All row reads as an action, not an entry.
            font.bold: row.modelData?.clearAll ?? false
            // Never render copied HTML — previews are always literal.
            textFormat: Text.PlainText
            // SearchRow's content Row only anchors left — cap the width
            // so long clipboard lines elide instead of overflowing.
            width: Theme.panelWidth - 6 * Theme.margin
            elide: Text.ElideRight
        }
    }
}

