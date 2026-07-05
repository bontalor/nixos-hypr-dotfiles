import "../components"
import "../util"
import "."
import QtQuick
import Quickshell
import Quickshell.Io

SearchPanel {
    id: root
    title: "Emoji Picker"
    maxLength: 10

    // MRU cap for the space-separated PrefStore.emojiRecents list.
    readonly property int recentsMax: 20

    property var allEmojis: []

    FileView {
        path: Paths.emojiData
        watchChanges: true
        onLoaded: root.parseEmojis(text())
        onFileChanged: root.parseEmojis(text())
    }

    function parseEmojis(text) {
        var lines = text.split("\n")
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "" || line.startsWith("#")) continue
            if (!line.includes("fully-qualified")) continue
            var hashIdx = line.indexOf("#")
            if (hashIdx === -1) continue
            var comment = line.substring(hashIdx + 1).trim()
            // comment looks like: 😀 E1.0 grinning face
            var parts = comment.split(" ")
            if (parts.length < 3) continue
            var emoji = parts[0]
            // skip the version (parts[1] = E1.0 etc)
            var name = parts.slice(2).join(" ")
            result.push({ char: emoji, name: name })
        }
        root.allEmojis = result
    }

    // Most-recently-used emoji, shown instead of the full multi-
    // thousand-row dump while the query is empty. Persisted as a
    // space-separated pref (emoji sequences never contain spaces).
    readonly property var recentChars: PrefStore.emojiRecents
        ? PrefStore.emojiRecents.split(" ") : []
    readonly property var recentItems: {
        var byChar = {}
        for (var i = 0; i < root.allEmojis.length; i++)
            byChar[root.allEmojis[i].char] = root.allEmojis[i]
        var out = []
        for (var j = 0; j < root.recentChars.length; j++) {
            var it = byChar[root.recentChars[j]]
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
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData?.char ?? ""
        }
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData?.name ?? ""
        }
    }
}