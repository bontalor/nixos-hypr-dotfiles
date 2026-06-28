import "../theme"
import "./widgets"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Scope {
    id: barRoot

    signal refreshNetwork()
    signal refreshBattery()

    IpcHandler {
        target: "refresh-network"
        function refresh(): void { barRoot.refreshNetwork() }
    }

    IpcHandler {
        target: "refresh-battery"
        function refresh(): void { barRoot.refreshBattery() }
    }

    // Long-lived event streams. Each monitor shells out to `qs ipc call` on
    // every event line; the matching IpcHandler above re-emits it as a QML
    // signal that the per-screen widgets react to. No polling timers anywhere.
    // (Media & volume widgets are fully event-driven via Quickshell's Mpris /
    // Pipewire services, so no media refresh relay is needed.)
    Process {
        running: true
        command: ["bash", "-c", "nmcli device monitor 2>/dev/null | while IFS= read -r line; do case \"$line\" in *\": connected\"|*\": disconnected\") qs ipc call refresh-network refresh; qs ipc call refresh-network-panel refresh ;; esac; done"]
    }

    Process {
        running: true
        command: ["bash", "-c", "upower --monitor 2>/dev/null | while IFS= read -r _; do qs ipc call refresh-battery refresh; done"]
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
                        var lay = ws.layout
                        if (lay === "dwindle" || lay === "master") return "Tiling"
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
                        font.pixelSize: 16
                        font.family: "JetBrainsMono Nerd Font"
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
                            target: barRoot
                            function onRefreshNetwork(): void { networkWidget.fetchStatus() }
                        }
                    }

                    VolumeWidget {
                        id: volumeWidget
                    }

                    BatteryWidget {
                        id: batteryWidget
                        Connections {
                            target: barRoot
                            function onRefreshBattery(): void { batteryWidget.refresh() }
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

