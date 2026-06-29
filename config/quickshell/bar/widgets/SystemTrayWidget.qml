import "../../theme"
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: root
    width: trayContent.width
    height: 30

    property var parentWindow

    // Max tray icons shown directly in the bar. Anything beyond this rolls
    // over into the dropdown opened by the chevron on the right.
    readonly property int maxVisible: 3

    component TrayIcon: Item {
        id: iconRoot
        required property var trayItem
        property var parentWindow
        width: 30
        height: 30

        Rectangle {
            anchors.fill: parent
            color: iconMouse.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
        }

        QsMenuAnchor {
            id: menuAnchor
            menu: iconRoot.trayItem.menu
            anchor.window: iconRoot.parentWindow
            anchor.item: iconRoot
            anchor.edges: Edges.Bottom | Edges.Left
        }

        IconImage {
            anchors.centerIn: parent
            width: 22
            height: 22
            source: iconRoot.trayItem.icon
            backer.sourceSize.width: 22 * Screen.devicePixelRatio
            backer.sourceSize.height: 22 * Screen.devicePixelRatio
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    if (iconRoot.trayItem.hasMenu) {
                        menuAnchor.open()
                    }
                } else if (mouse.button === Qt.LeftButton) {
                    iconRoot.trayItem.activate()
                }
            }
        }
    }

    Row {
        id: trayContent
        spacing: 10

        // Up to `maxVisible` icons live directly in the bar.
        Repeater {
            model: Math.min(root.maxVisible, SystemTray.items.values.length)
            delegate: TrayIcon {
                required property int index
                trayItem: SystemTray.items.values[index]
                parentWindow: root.parentWindow
            }
        }

        // Chevron on the very right: only present when there's overflow.
        Item {
            id: chevronItem
            width: 30
            height: 30
            visible: SystemTray.items.values.length > root.maxVisible

            Rectangle {
                anchors.fill: parent
                color: chevronMouse.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
            }

            Text {
                anchors.centerIn: parent
                text: overflowPopup.visible ? "\u{F0143}" : "\u{F0140}"
                color: Colors.foreground
                font.pixelSize: 22
                font.family: Theme.fontFamily
            }

            MouseArea {
                id: chevronMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: overflowPopup.visible = !overflowPopup.visible
            }
        }
    }

    PanelWindow {
        id: overflowPopup
        visible: false
        screen: root.parentWindow.screen
        color: "transparent"
        implicitWidth: 30
        implicitHeight: overflowColumn.height + 20
        focusable: false
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        WlrLayershell.namespace: "quickshell:tray"
        anchors {
            top: true
            left: true
        }

        // Position the dropdown exactly under the chevron button when the
        // popup opens. `itemPosition` returns the chevron's screen-
        // absolute coordinates (already accounting for the bar's 10px
        // layer-shell margins), so:
        //   dropdown top  = chevronY + 30  (chevron height, flush below)
        //   dropdown left = chevronX      (aligns with chevron left edge)
        onVisibleChanged: if (visible) {
            var pos = root.parentWindow.itemPosition(chevronItem)
            margins.top = pos.y -10
            margins.left = pos.x + 10
        }

        // As soon as overflow disappears (tray drops to <= maxVisible),
        // dismiss the popup so it doesn't dangle empty with no chevron.
        Connections {
            target: SystemTray.items
            function onValuesChanged() {
                if (SystemTray.items.values.length <= root.maxVisible)
                    overflowPopup.visible = false
            }
        }

        Shortcut { sequence: "Escape"; onActivated: overflowPopup.visible = false }

        Rectangle {
            id: overflowBackground
            anchors.fill: parent
            color: Qt.alpha(Colors.background, 0.76)

            Column {
                id: overflowColumn
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 10

                Repeater {
                    model: Math.max(0, SystemTray.items.values.length - root.maxVisible)
                    delegate: TrayIcon {
                        required property int index
                        trayItem: SystemTray.items.values[index + root.maxVisible]
                        parentWindow: overflowPopup
                    }
                }
            }
        }
    }
}
