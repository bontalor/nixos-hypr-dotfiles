import "../theme"
import "./widgets"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
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

                Item {
                    id: layoutState
                    anchors.left: workspaces.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: stateText.width + 20
                    height: 30

                    property string displayState: "Tile"

                    function updateState() {
                        stateProc.command = ["bash", "-c",
                            "echo '###WORKSPACE'; hyprctl activeworkspace -j 2>/dev/null; echo '###ACTIVE'; hyprctl activewindow -j 2>/dev/null; echo '###CLIENTS'; hyprctl clients -j 2>/dev/null"]
                        stateProc.running = true
                    }

                    Process {
                        id: stateProc
                        running: false
                        stdout: StdioCollector {
                            waitForEnd: true
                            onStreamFinished: {
                                var sections = text.split("###")
                                var wsData = null
                                var activeData = null
                                var clientsData = null
                                for (var si = 0; si < sections.length; si++) {
                                    var sec = sections[si].trim()
                                    if (sec.indexOf("WORKSPACE") === 0) {
                                        try { wsData = JSON.parse(sec.substring(9).trim()) } catch (e) {}
                                    } else if (sec.indexOf("ACTIVE") === 0) {
                                        try { activeData = JSON.parse(sec.substring(6).trim()) } catch (e) {}
                                    } else if (sec.indexOf("CLIENTS") === 0) {
                                        try { clientsData = JSON.parse(sec.substring(7).trim()) } catch (e) {}
                                    }
                                }
                                if (!wsData) { layoutState.displayState = "Tile"; return }
                                var wsId = wsData.id
                                var lay = wsData.layout

                                var full = false
                                var maxd = false

                                if (activeData && activeData.workspace && activeData.workspace.id === wsId) {
                                    if (activeData.fullscreen === 2) full = true
                                    else if (activeData.fullscreen === 1) maxd = true
                                }

                                if (clientsData && Array.isArray(clientsData)) {
                                    for (var i = 0; i < clientsData.length; i++) {
                                        var c = clientsData[i]
                                        if (!c.workspace || c.workspace.id !== wsId) continue
                                        if (c.fullscreen === 2 || c.fullscreenClient === 2) full = true
                                        else if (c.fullscreen === 1 || c.fullscreenClient === 1) maxd = true
                                    }
                                }

                                if (full) { layoutState.displayState = "Fullscreen"; return }
                                if (maxd) { layoutState.displayState = "Maximized"; return }
                                if (lay === "dwindle" || lay === "master") { layoutState.displayState = "Tiling"; return }
                                layoutState.displayState = "Tiling"
                            }
                        }
                    }

                    Connections {
                        target: Hyprland
                        function onRawEvent(event) {
                            if (event.name === "fullscreen" || event.name === "window" || event.name === "focusedmon" || event.name === "workspace") {
                                layoutState.updateState()
                            }
                        }
                    }

                    Timer {
                        id: stateTimer
                        interval: 300
                        repeat: true
                        running: true
                        onTriggered: layoutState.updateState()
                    }

                    Component.onCompleted: layoutState.updateState()

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

