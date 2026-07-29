// Subprocess dependency: wl-copy (copies emoji to clipboard via
// Wayland data device).

import "../components"
import "../util"
import "."
import QtQuick
import Quickshell
import Quickshell.Io

pragma ComponentBehavior: Bound

SearchPanel {
    id: root
    title: "Emoji Picker"
    maxLength: 10

    // MRU cap for the space-separated PrefStore.emojiRecents list.
    readonly property int recentsMax: 20

    property var allEmojis: []
    property var _byChar: ({})   // char -> entry, built once on parse

    FileView {
        path: Paths.emojiData
        // emoji-test.txt is static Unicode data — no need to watch
        // for filesystem changes (a backup tool touching the file
        // would otherwise re-parse the whole ~5000-line file).
        onLoaded: root.parseEmojis(text())
    }

    function parseEmojis(text) {
        var lines = text.split("\n")
        var result = []
        var byChar = {}
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "" || line.startsWith("#")) continue
            if (!line.includes("fully-qualified")) continue
            var hashIdx = line.indexOf("#")
            if (hashIdx === -1) continue
            var comment = line.substring(hashIdx + 1).trim()
            var parts = comment.split(" ")
            if (parts.length < 3) continue
            var emoji = parts[0]
            var name = parts.slice(2).join(" ")
            var entry = { char: emoji, name: name }
            result.push(entry)
            byChar[emoji] = entry
        }
        root._byChar = byChar
        root.allEmojis = result
    }

    readonly property var recentChars: PrefStore.emojiRecents
        ? PrefStore.emojiRecents.split(" ") : []
    readonly property var recentItems: {
        var out = []
        for (var j = 0; j < root.recentChars.length; j++) {
            var it = root._byChar[root.recentChars[j]]
            if (it) out.push(it)
        }
        return out
    }

    items: root.query === "" && root.recentItems.length > 0
        ? root.recentItems : root.allEmojis

    // Distinguish "data file missing/unparsed" from "no search hits" —
    // a silently blank picker looks like a shell bug.
    emptyText: root.allEmojis.length === 0
        ? "No emoji data — expected Unicode emoji-test.txt at " + Paths.emojiData
        : "No matches"

    onLaunched: function(idx) {
        var emoji = root.filtered[idx]
        if (!emoji) return
        copyProcess.command = ["wl-copy", emoji.char]
        copyProcess.running = true
        var next = [emoji.char].concat(root.recentChars.filter(function(c) {
            return c !== emoji.char
        })).slice(0, root.recentsMax)
        PrefStore.emojiRecents = next.join(" ")
        root.visible = false
    }

    CheckedProcess {
        id: copyProcess
        label: "wl-copy"
        running: false
    }

    rowDelegate: SearchRow {
        id: emojiRow
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: emojiRow.modelData?.char ?? ""
        }
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: emojiRow.modelData?.name ?? ""
        }
    }
}