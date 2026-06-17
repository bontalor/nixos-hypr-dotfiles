import "theme"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
Rectangle {
    id: root
    required property LockContext context
    color: "transparent"
    property string wallpaperPath: ""
    Process {
        id: wallpaperReader
        command: ["cat", Quickshell.env("HOME") + "/.cache/wal/wal"]
        running: true
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.wallpaperPath = text.trim()
        }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/wal"
        watchChanges: true
        onFileChanged: wallpaperReader.running = true
    }
    Image {
        anchors.fill: parent
        source: wallpaperPath ? "file://" + wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
    }
    Process {
        id: btnProcess
        running: false
    }
    Rectangle {
        id: panel
        x: 10
        y: 10
        width: parent.width - 30
        height: parent.height - 30
        color: Qt.alpha(Colors.background, 0.76)
        Column {
            anchors.centerIn: parent
            width: 420
            spacing: 10
            Item {
                width: parent.width
                height: 60
                SystemClock {
                    id: clock
                    precision: SystemClock.Seconds
                }
                Text {
                    anchors.centerIn: parent
                    color: Colors.foreground
                    font.pixelSize: 32
                    font.family: "JetBrainsMono Nerd Font"
                    font.bold: true

                    text: {
                        var d = clock.date
                        var h = d.getHours().toString().padStart(2, "0")
                        var m = d.getMinutes().toString().padStart(2, "0")
                        var s = d.getSeconds().toString().padStart(2, "0")
                        return h + ":" + m + ":" + s
                    }
                }
            }
            Item {
                width: parent.width
                height: 20
                Text {
                    anchors.centerIn: parent
                    color: Qt.alpha(Colors.foreground, 0.75)
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    function ordinal(n) {
                        var s = ["th","st","nd","rd"]
                        var v = n % 100
                        return n + (s[(v-20)%10] || s[v] || s[0])
                    }
                    text: {
                        var d = clock.date
                        return Qt.formatDateTime(d, "dddd, MMMM ") + ordinal(d.getDate()) + Qt.formatDateTime(d, ", yyyy")
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 30
                color: Qt.alpha(Colors.background, 0.75)
                clip: true
                TextInput {
                    id: passwordBox
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                        rightMargin: 10
                    }
                    color: Colors.foreground
                    font.pixelSize: 16
                    font.letterSpacing: 10
                    font.family: "JetBrainsMono Nerd Font"
                    focus: true
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData
                    onTextChanged: root.context.currentText = this.text
                    onAccepted: root.context.tryUnlock()
                    Text {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 10
                        }
                        color: Qt.alpha(Colors.foreground, 0.75)
                        font.pixelSize: 16
                        font.family: "JetBrainsMono Nerd Font"
                        text: "Enter password..."
                        visible: parent.text.length === 0 && !parent.focus
                    }
                    Connections {
                        target: root.context
                        function onCurrentTextChanged() {
                            if (passwordBox.text !== root.context.currentText) {
                                passwordBox.text = root.context.currentText
                            }
                        }
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 45
                Repeater {
                    model: [
                        { name: "Logout", icon: "system-log-out", command: ["sh", "-c", "loginctl kill-session $XDG_SESSION_ID"] },
                        { name: "Suspend", icon: "system-suspend", command: ["systemctl", "suspend"] },
                        { name: "Reboot", icon: "system-reboot", command: ["systemctl", "reboot"] },
                        { name: "Power Off", icon: "system-shutdown", command: ["systemctl", "poweroff"] }
                    ]
                    delegate: Column {
                        spacing: 4
                        width: 60
                        Rectangle {
                            width: 45
                            height: 45
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: btnMouse.containsMouse ? Qt.alpha(Colors.base08, 0.75) : Qt.alpha(Colors.background, 0.75)
                            IconImage {
                                anchors.centerIn: parent
                                source: modelData?.icon ? Quickshell.iconPath(modelData.icon, false) : ""
                                width: 22; height: 22
                                visible: source.toString() !== ""
                            }
                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    btnProcess.command = modelData.command
                                    btnProcess.running = true
                                }
                            }
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData?.name ?? ""
                            color: Colors.foreground
                            font.pixelSize: 16
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }
                }
            }
            Item {
                width: parent.width
                height: 20
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: context.showFailure
                    text: "Incorrect password"
                    color: Colors.base08
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                }
            }
        }
    }
    Rectangle {
        id: shadowBottom
        x: 20
        y: parent.height - 20
        width: parent.width - 30
        height: 10
        color: Qt.alpha("#000000", 0.75)
    }
    Rectangle {
        id: shadowRight
        x: parent.width - 20
        y: 20
        width: 10
        height: parent.height - 40
        color: Qt.alpha("#000000", 0.75)
    }
}
