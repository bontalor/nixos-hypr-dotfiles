import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

FloatingWindow {
    id: root
    title: "Power Menu"
    color: "transparent"
    implicitWidth: 300
    implicitHeight: 250
    visible: false

    onClosed: visible = false

    property var allActions: [
        { name: "Lock", icon: "system-lock-screen", command: ["quickshell", "-p", Quickshell.shellDir + "/lockscreen/shell.qml"] },
	{ name: "Logout", icon: "system-log-out", command: ["loginctl", "terminate-user", ""] },
        { name: "Suspend", icon: "system-suspend", command: ["systemctl", "suspend"] },
        { name: "Reboot", icon: "system-reboot", command: ["systemctl", "reboot"] },
        { name: "Power Off", icon: "system-shutdown", command: ["systemctl", "poweroff"] }
    ]

    property int selectedIndex: 0

    property var filteredActions: {
        var q = searchText.text.trim().toLowerCase()

        if (q === "") return allActions

        var matches = allActions.filter(function(a) { return a.name && a.name.toLowerCase().includes(q) })

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

        return matches
    }

    function executeSelected() {
        if (filteredActions.length === 0) return
        var action = filteredActions[selectedIndex]
        runner.command = action.command
        runner.running = true
        root.visible = false
    }

    Process {
        id: runner
        running: false
    }

    onVisibleChanged: {
        if (visible) {
            searchText.text = ""
            selectedIndex = 0
            searchText.forceActiveFocus()
        }
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
                color: Qt.alpha(Colors.base00, 1)

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
                            selectedIndex = Math.min(selectedIndex + 1, filteredActions.length - 1)
                            event.accepted = true; break
                        case Qt.Key_Up:
                            selectedIndex = Math.max(selectedIndex - 1, 0)
                            event.accepted = true; break
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            executeSelected()
                            event.accepted = true; break
                        case Qt.Key_Escape:
                            root.visible = false
                            event.accepted = true; break
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 10

                Repeater {
                    model: filteredActions

                    delegate: Rectangle {
                        width: parent.width
                        height: 30
                        color: index === selectedIndex ? Qt.alpha(Colors.base01, 0.75) : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 10

                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                source: modelData?.icon ? Quickshell.iconPath(modelData.icon, false) : ""
                                width: 22; height: 22
                                visible: source.toString() !== ""
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
                            onClicked: { selectedIndex = index; executeSelected() }
                        }
                    }
                }
            }
        }
    }
}
