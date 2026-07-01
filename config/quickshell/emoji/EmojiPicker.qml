import "../theme"
import "../util"
import "."
import QtQuick
import Quickshell
import Quickshell.Io

SearchPanel {
    id: root
    title: "Emoji Picker"
    maxLength: 10

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

    items: root.allEmojis

    onLaunched: function(idx) {
        var emoji = root.filtered[idx]
        if (!emoji) return
        copyProcess.command = ["wl-copy", emoji.char]
        copyProcess.running = true
        root.visible = false
    }

    Process {
        id: copyProcess
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