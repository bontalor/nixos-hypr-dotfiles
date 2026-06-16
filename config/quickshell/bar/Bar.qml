import "../theme"
import "./widgets"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

Scope {
    QtObject {
        id: ipcSignals
        signal refreshNetwork()
        signal refreshBattery()
        signal refreshMedia()
    }

    IpcHandler {
        target: "refresh-network"
        function refresh(): void { ipcSignals.refreshNetwork() }
    }

    IpcHandler {
        target: "refresh-battery"
        function refresh(): void { ipcSignals.refreshBattery() }
    }

    IpcHandler {
        target: "refresh-media"
        function refresh(): void { ipcSignals.refreshMedia() }
    }

    Variants {
        model: Quickshell.screens;
        PanelWindow {
            id: panelWindow // Added unique window reference id
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "quickshell:bar"
            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                top: 10
                right: 10
                left: 10
            }
            color: "transparent"
            implicitHeight: 40
            Rectangle {
                id: bar
                x: 0
                y: 0
                width: parent.width - 10
                height: 30
                color: Qt.alpha(Colors.background, 0.76)
                z: 1
                DistroWidget {
                    id: distroWidget
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                }

                WorkspacesWidget {
                    id: workspaces
                    anchors.left: distroWidget.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                }

                MediaWidget {
                    id: mediaWidget
                    anchors.right: clockWidget.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: clockWidget.verticalCenter
                    Connections {
                        target: ipcSignals
                        function onRefreshMedia(): void { mediaWidget.refreshPlayer() }
                    }
                }

                Item {
                    id: clockWidget
                    width: clockText.width + 20
                    height: 30
                    anchors.centerIn: parent

                    Rectangle {
                        anchors.fill: parent
                        color: clockMouse.containsMouse ? Qt.alpha(Colors.base08, 0.75) : "transparent"
                    }

                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        text: Time.time
                        font.pixelSize: 16
                        font.family: "JetBrainsMono Nerd Font"
                        color: Colors.foreground
                    }

                    MouseArea {
                        id: clockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clockToggle.running = true
                    }

                    Process {
                        id: clockToggle
                        command: ["qs", "ipc", "call", "overlay", "toggle", "datetime"]
                        running: false
                    }
                }

                WeatherWidget {
                    anchors.left: clockWidget.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: clockWidget.verticalCenter
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    layoutDirection: Qt.RightToLeft

                    SystemTrayWidget {
                        id: sysTray
                        parentWindow: panelWindow
                    }

                    NetworkWidget {
                        id: networkWidget
                        Connections {
                            target: ipcSignals
                            function onRefreshNetwork(): void { networkWidget.fetchStatus() }
                        }
                    }

                    VolumeWidget {
                        id: volumeWidget
                    }

                    BatteryWidget {
                        id: batteryWidget
                        Connections {
                            target: ipcSignals
                            function onRefreshBattery(): void { batteryWidget.fetchStatus() }
                        }
                    }
                }
            }

            Rectangle {
                id: shadowBottom
                x: 10
                y: 30
                width: parent.width - 10
                height: 10
                color: Qt.alpha("#000000", 0.75)
                z: 0
            }
            Rectangle {
                id: shadowRight
                x: parent.width - 10
                y: 10
                width: 10
                height: 20
                color: Qt.alpha("#000000", 0.75)
                z: 0
            }
        }
    }
}
