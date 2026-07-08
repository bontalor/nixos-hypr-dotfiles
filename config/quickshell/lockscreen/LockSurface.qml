// Subprocess dependencies: systemctl (suspend/reboot/poweroff),
// loginctl (terminate-user logout) — same power actions as PowerMenu.

import "./theme"
import "./components"
import "./util"
import "./models"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
Rectangle {
    id: root
    required property LockContext context
    color: Colors.background

    property string wallpaperPath: ""

    // blockLoading: true makes the initial text() call synchronous — the
    // onLoaded signal fires before the first frame is rendered, so
    // wallpaperPath is set (and Image starts decoding) before any paint.
    FileView {
        path: Paths.walWallpaper
        blockLoading: true
        watchChanges: true
        onLoaded: root.wallpaperPath = text().trim()
        onFileChanged: root.wallpaperPath = text().trim()
    }

    Image {
        anchors.fill: parent
        source: wallpaperPath ? "file://" + wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: false   // decode synchronously so first frame shows wallpaper
        sourceSize.width: 1920
        sourceSize.height: 1080
    }
    Process {
        id: btnProcess
        running: false
    }

    property string formattedDate: FormatUtil.formattedDate(clock.date)

    property var lockActions: PowerActions.actions.filter(function(a) {
        return a.name !== "Lock"
    })

    Rectangle {
        id: panel
        x: (parent.width - Theme.panelWidth) / 2
        y: (parent.height - Theme.panelHeight) / 2
        width: Theme.panelWidth - Theme.margin
        height: Theme.panelHeight - Theme.margin
        color: Qt.alpha(Colors.background, Theme.alphaWindow)
        Column {
            anchors.centerIn: parent
            width: 420
            spacing: Theme.margin
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
                    text: Qt.formatDateTime(clock.date, PrefStore.timeFormat === "24h" ? "HH:mm:ss" : "h:mm:ss AP")
                }
            }
            Item {
                width: parent.width
                height: 20
                ThemeText {
                    anchors.centerIn: parent
                    text: root.formattedDate
                }
            }
            Row {
                width: parent.width
                height: Theme.headerHeight
                spacing: context.fingerprintEnabled ? Theme.margin : 0
                Rectangle {
                    width: parent.width - (context.fingerprintEnabled ? 40 : 0)
                    height: Theme.headerHeight
                    color: Qt.alpha(Colors.background, Theme.alphaBackground)
                    clip: true
                    TextInput {
                        id: passwordBox
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: Theme.margin
                            rightMargin: Theme.margin
                        }
                        color: Colors.foreground
                        font.pixelSize: Theme.fontPixelSize
                        font.letterSpacing: 10
                        font.family: Theme.fontFamily
                        focus: true
                        echoMode: TextInput.Password
                        passwordCharacter: "■"
                        inputMethodHints: Qt.ImhSensitiveData
                        onTextChanged: root.context.currentText = this.text
                        onAccepted: root.context.tryUnlock()
                        Text {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                                leftMargin: Theme.margin
                            }
                            color: Colors.foreground
                            font.pixelSize: Theme.fontPixelSize
                            font.family: Theme.fontFamily
                            text: "Enter password..."
                            visible: parent.text.length === 0
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
                Rectangle {
                    width: context.fingerprintEnabled ? 30 : 0
                    height: Theme.headerHeight
                    visible: context.fingerprintEnabled
                    color: context.fingerprintFailed
                        ? Qt.alpha(Colors.critical, Theme.alphaBackground)
                        : Qt.alpha(Colors.background, Theme.alphaBackground)
                    ThemeText {
                        anchors.centerIn: parent
                        text: Icon.fingerprint
                        size: "large"
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
                            color: btnMouse.containsMouse ? Qt.alpha(Colors.accent, Theme.alphaSectionHeader + Theme.alphaHover) : Qt.alpha(Colors.accent, Theme.alphaSectionHeader)
                            ThemeText {
                                anchors.centerIn: parent
                                text: modelData?.glyph ?? ""
                                size: "large"
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
                        ThemeText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData?.name ?? ""
                        }
                    }
                }
            }
            Item {
                width: parent.width
                height: 20
                ThemeText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: context.fingerprintScanning
                    text: "waiting for scan..."
                }
            }
        }
        ThemeText {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.margin
            anchors.horizontalCenter: parent.horizontalCenter
            visible: context.showFailure
            text: "Incorrect password"
        }
    }
    DropShadow {
        x: panel.x
        y: panel.y
        width: panel.width + Theme.margin
        height: panel.height + Theme.margin
    }
}
