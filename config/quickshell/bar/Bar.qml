import "../theme"
import "./widgets"
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

Scope {
    id: barRoot

    // Network + battery state comes from NetworkModel / BatteryModel
    // (D-Bus-backed live properties). No monitor loops, no self-IPC.

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

                Item {
                    id: layoutState
                    anchors.left: workspaces.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: stateText.width + 20
                    height: 30

                    property string displayState: {
                        var ws = Hyprland.focusedWorkspace
                        if (!ws) return "Tiling"
                        var wsId = ws.id
                        var toplevels = Hyprland.toplevels.values
                        var full = false
                        var maxd = false
                        for (var i = 0; i < toplevels.length; i++) {
                            var c = toplevels[i]
                            if (!c.workspace || c.workspace.id !== wsId) continue
                            if (c.fullscreen === 2 || c.fullscreenClient === 2) full = true
                            else if (c.fullscreen === 1 || c.fullscreenClient === 1) maxd = true
                        }
                        if (full) return "Fullscreen"
                        if (maxd) return "Maximized"
                        return "Tiling"
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: layoutMouse.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
                    }

                    Text {
                        id: stateText
                        anchors.centerIn: parent
                        text: layoutState.displayState
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                        color: Colors.foreground
                    }

                    MouseArea {
                        id: layoutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                MediaWidget {
                    id: mediaWidget
                    anchors.right: clockWidget.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: clockWidget.verticalCenter
                }

                Item {
                    id: clockWidget
                    width: clockText.width + 20
                    height: 30
                    anchors.centerIn: parent

                    Rectangle {
                        anchors.fill: parent
                        color: clockMouse.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
                    }

                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        text: Time.time
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                        color: Colors.foreground
                    }

                    MouseArea {
                        id: clockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Panels.toggle("datetime")
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
                    }

                    VolumeWidget {
                        id: volumeWidget
                    }

                    BatteryWidget {
                        id: batteryWidget
                    }
                }
            }

            Rectangle {
                id: shadowBottom
                x: 10
                y: 30
                width: parent.width - 10
                height: 10
                color: Qt.alpha("#000000", Theme.alphaBackground)
                z: 0
            }
            Rectangle {
                id: shadowRight
                x: parent.width - 10
                y: 10
                width: 10
                height: 20
                color: Qt.alpha("#000000", Theme.alphaBackground)
                z: 0
            }
        }
    }
}

