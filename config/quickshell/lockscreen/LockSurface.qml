import "./theme"
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

    // Inline helper — the lockscreen runs as its own config root via
    // `quickshell -p lockscreen/shell.qml`, so the shared ../util singleton
    // isn't reachable. Keeping the lone function local avoids entangling
    // the lockscreen with the rest of the shell.
    function ordinal(n) {
        var s = ["th", "st", "nd", "rd"]
        var v = n % 100
        return n + (s[(v - 20) % 10] || s[v] || s[0])
    }

    // Same shape as PowerActions.lockActions, kept local for config-root
    // isolation. The lockscreen's actions never overlap with anything else
    // (no Lock on the lockscreen), so a duplicated 4-item list is fine.
    property var lockActions: [
        { name: "Logout",    icon: "system-log-out",  command: ["sh", "-c", "loginctl kill-session \"${XDG_SESSION_ID:-$(loginctl list-sessions --no-legend | head -n1 | awk '{print $1}')}\""] },
        { name: "Suspend",   icon: "system-suspend",  command: ["systemctl", "suspend"] },
        { name: "Reboot",    icon: "system-reboot",   command: ["systemctl", "reboot"] },
        { name: "Power Off", icon: "system-shutdown", command: ["systemctl", "poweroff"] }
    ]

    FileView {
        id: wallpaperFile
        path: Quickshell.env("HOME") + "/.cache/wal/wal"
        watchChanges: true
        onLoaded: root.wallpaperPath = text().trim()
        onFileChanged: root.wallpaperPath = text().trim()
    }
    Image {
        anchors.fill: parent
        source: wallpaperPath ? "file://" + wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 1920
        sourceSize.height: 1080
    }
    Process {
        id: btnProcess
        running: false
    }

    property string formattedDate: {
        var d = clock.date
        return Qt.formatDateTime(d, "dddd, MMMM ") + root.ordinal(d.getDate()) + Qt.formatDateTime(d, ", yyyy")
    }

    property int panelWidth: 850
    property int panelHeight: 450

    Rectangle {
        id: panel
        x: (parent.width - panelWidth) / 2
        y: (parent.height - panelHeight) / 2
        width: panelWidth - 10
        height: panelHeight - 10
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
                    font.family: Theme.fontFamily
                    font.bold: true

                    text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                }
            }
            Item {
                width: parent.width
                height: 20
                Text {
                    anchors.centerIn: parent
                    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    text: root.formattedDate
                }
            }
            Rectangle {
                width: parent.width
                height: 30
                color: Qt.alpha(Colors.background, Theme.alphaBackground)
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
                    font.pixelSize: Theme.fontPixelSize
                    font.letterSpacing: 10
                    font.family: Theme.fontFamily
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
                        color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
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
            Item {
                width: parent.width
                height: 20
                visible: context.fingerprintEnabled
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    IconImage {
                        source: Quickshell.iconPath("fingerprint", false)
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: source.toString() !== ""
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: context.fingerprintHint
                        color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 45
                Repeater {
                    model: root.lockActions
                    delegate: Column {
                        spacing: 4
                        width: 60
                        Rectangle {
                            width: 45
                            height: 45
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: btnMouse.containsMouse ? Qt.alpha(Colors.base08, Theme.alphaBackground) : Qt.alpha(Colors.background, Theme.alphaBackground)
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
                            font.pixelSize: Theme.fontPixelSize
                            font.family: Theme.fontFamily
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
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }
            }
        }
    }
    Rectangle {
        id: shadowBottom
        x: panel.x + 10
        y: panel.y + panel.height
        width: panel.width - 10
        height: 10
        color: Qt.alpha("#000000", Theme.alphaBackground)
    }
    Rectangle {
        id: shadowRight
        x: panel.x + panel.width
        y: panel.y + 10
        width: 10
        height: panel.height
        color: Qt.alpha("#000000", Theme.alphaBackground)
    }
}
