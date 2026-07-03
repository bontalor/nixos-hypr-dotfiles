import "../theme"
import "../util"
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
            id: panelWindow
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "quickshell:bar"

            // Bar edge follows the Settings pref. The window's internal
            // layout is identical either way: bar Rectangle at the top,
            // drop shadow in the extra barMargin below it.
            readonly property bool barAtBottom: PrefStore.barPosition === "bottom"

            anchors {
                top: !panelWindow.barAtBottom
                bottom: panelWindow.barAtBottom
                left: true
                right: true
            }
            margins {
                top: panelWindow.barAtBottom ? 0 : Theme.barMargin
                bottom: panelWindow.barAtBottom ? Theme.barMargin : 0
                right: Theme.barMargin
                left: Theme.barMargin
            }
            color: "transparent"
            implicitHeight: Theme.barHeight + Theme.barMargin
            Rectangle {
                id: bar
                x: 0
                y: 0
                width: parent.width - Theme.barMargin
                height: Theme.barHeight
                color: Qt.alpha(Colors.background, Theme.alphaWindow)
                z: 1
                DistroWidget {
                    id: distroWidget
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.barMargin
                    anchors.verticalCenter: parent.verticalCenter
                }

                WorkspacesWidget {
                    id: workspaces
                    anchors.left: distroWidget.right
                    anchors.leftMargin: Theme.barMargin
                    anchors.verticalCenter: parent.verticalCenter
                }

                MediaWidget {
                    id: mediaWidget
                    anchors.right: clockWidget.left
                    anchors.rightMargin: Theme.barMargin
                    anchors.verticalCenter: clockWidget.verticalCenter
                }

                ClockWidget {
                    id: clockWidget
                    anchors.centerIn: parent
                }

                WeatherWidget {
                    anchors.left: clockWidget.right
                    anchors.leftMargin: Theme.barMargin
                    anchors.verticalCenter: clockWidget.verticalCenter
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.barMargin
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.barMargin
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

                    NotifWidget {}
                }
            }

            // Shared drop-shadow component. Sized to include the shadow
            // extent (bar width + margin, bar height + margin) so the
            // internal L-shaped strips align with the bar's right/bottom edges.
            DropShadow {
                x: 0
                y: 0
                width: bar.width + Theme.margin
                height: Theme.barHeight + Theme.margin
                z: 0
            }
        }
    }
}
