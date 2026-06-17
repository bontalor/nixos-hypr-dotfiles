import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

FloatingWindow {
    id: root
    title: "Emoji Picker"
    color: "transparent"
    implicitWidth: 850
    implicitHeight: 460
    visible: false

    onClosed: visible = false

    property var allEmojis: []
    property int selectedIndex: 0

    Process {
        id: emojiLoader
	command: [
	    "cat", Quickshell.env("HOME") + "/.local/share/emoji-test.txt"
	]
        running: true
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
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
        }
    }

    property var filteredEmojis: {
        var q = searchText.text.trim().toLowerCase()
        if (q === "") return allEmojis.slice(0, 10)
        var matches = allEmojis.filter(function(e) { return e.name && e.name.toLowerCase().includes(q) })
        matches.sort(function(a, b) {
            var aName = a.name.toLowerCase()
            var bName = b.name.toLowerCase()
            var aIdx = aName.indexOf(q)
            var bIdx = bName.indexOf(q)
            if (aIdx === 0 && bIdx !== 0) return -1
            if (bIdx === 0 && aIdx !== 0) return 1
            if (aName.length !== bName.length) return aName.length - bName.length
            if (aIdx !== bIdx) return aIdx - bIdx
            if (aName < bName) return -1
            if (aName > bName) return 1
            return 0
        })
        return matches.slice(0, 10)
    }

    function launchSelected() {
        if (filteredEmojis.length === 0) return
        var emoji = filteredEmojis[selectedIndex]
        copyProcess.command = ["wl-copy", emoji.char]
        copyProcess.running = true
        root.visible = false
    }

    Process {
        id: copyProcess
        running: false
    }

    onVisibleChanged: {
        if (visible) {
            searchText.text = ""
            selectedIndex = 0
            searchText.forceActiveFocus()
        }
    }

    onSelectedIndexChanged: {
        if (resultFlick) resultFlick.scrollToSelected()
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                width: parent.width
                height: 30
                color: Qt.alpha(Colors.base00, 0.75)
                clip: true

                TextInput {
                    id: searchText
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                        rightMargin: 10
                    }
                    color: Colors.foreground
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    onTextChanged: selectedIndex = 0

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Down:
                            selectedIndex = Math.min(selectedIndex + 1, filteredEmojis.length - 1)
                            event.accepted = true; break
                        case Qt.Key_Up:
                            selectedIndex = Math.max(selectedIndex - 1, 0)
                            event.accepted = true; break
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            launchSelected()
                            event.accepted = true; break
                        case Qt.Key_Escape:
                            root.visible = false
                            event.accepted = true; break
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: parent.height - 40
                color: Qt.alpha(Colors.base00, 0.75)

                Flickable {
                    id: resultFlick
                    anchors.fill: parent
                    anchors.margins: 10
                    contentHeight: resultCol.height
                    clip: true

                    function scrollToSelected() {
                        var y = selectedIndex * 40
                        var h = 30
                        var viewH = resultFlick.height
                        var maxY = Math.max(0, resultCol.height - viewH)
                        if (y < resultFlick.contentY) {
                            resultFlick.contentY = Math.max(0, y - 10)
                        } else if (y + h > resultFlick.contentY + viewH) {
                            resultFlick.contentY = Math.min(maxY, y + h - viewH + 10)
                        }
                    }

                    Column {
                        id: resultCol
                        width: parent.width
                        spacing: 10

                        Repeater {
                            model: filteredEmojis

                            delegate: Rectangle {
                                width: parent.width
                                height: 30
                                color: index === selectedIndex ? Qt.alpha(Colors.base01, 0.75) : "transparent"

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    spacing: 10

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData?.char ?? ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData?.name ?? ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { selectedIndex = index; launchSelected() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
