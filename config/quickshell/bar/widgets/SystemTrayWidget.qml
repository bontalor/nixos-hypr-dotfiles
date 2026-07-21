import "../../theme"
import "../../components"
import "../../util"
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Widgets

pragma ComponentBehavior: Bound

Item {
    id: root
    width: trayContent.width
    height: Theme.barHeight

    property var parentWindow

    // Max tray icons shown directly in the bar. Anything beyond this rolls
    // over into the dropdown opened by the chevron on the right.
    readonly property int maxVisible: Theme.trayMaxVisible

    component TrayIcon: Item {
        id: iconRoot
        required property var trayItem
        property var parentWindow
        width: Theme.barHeight
        height: Theme.barHeight

        Rectangle {
            anchors.fill: parent
            color: iconMouse.containsMouse ? Qt.alpha(Colors.foreground, Theme.alphaHover) : "transparent"
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
            width: Theme.iconSize
            height: Theme.iconSize
            source: iconRoot.trayItem.icon
            backer.sourceSize.width: Theme.iconSize * Screen.devicePixelRatio
            backer.sourceSize.height: Theme.iconSize * Screen.devicePixelRatio
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
        spacing: Theme.margin

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
            width: Theme.barHeight
            height: Theme.barHeight
            visible: SystemTray.items.values.length > root.maxVisible

            Rectangle {
                anchors.fill: parent
                color: chevronMouse.containsMouse ? Qt.alpha(Colors.foreground, Theme.alphaHover) : "transparent"
            }

            ThemeText {
                anchors.centerIn: parent
                text: overflowPopup.visible ? Icon.chevronCollapse : Icon.chevronExpand
                size: "large"
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
        implicitWidth: Theme.barHeight
        implicitHeight: overflowColumn.height + 2 * Theme.margin
        focusable: false
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        WlrLayershell.namespace: "quickshell:tray"
        // Anchor the popup flush below (top-bar) or above (bottom-bar)
        // the bar — the previous `top: true; left: true` only + a
        // mirror formula never actually placed the popup above the
        // chevron for the bottom case, since neither `bottom` anchor
        // nor the screen height were consulted.
        anchors {
            top: !root.parentWindow.barAtBottom
            bottom: root.parentWindow.barAtBottom
            left: true
        }

        // Vertical offset from the popup's anchor edge: bar margin +
        // bar height clears the bar, plus a small Theme.margin gap.
        // Horizontal: align the popup's left edge with the chevron's
        // left edge (offset by Theme.margin for visual breathing room).
        // `itemPosition` returns the chevron's coordinates relative to
        // the bar window's content surface; since both the popup and
        // the bar ultimately alignto the same screen edges, this gives
        // a consistent horizontal offset regardless of which side the
        // bar sits on.
        onVisibleChanged: if (visible) {
            var pos = root.parentWindow.itemPosition(chevronItem)
            var vClear = Theme.barMargin + Theme.barHeight + Theme.margin
            margins.top = root.parentWindow.barAtBottom ? 0 : vClear
            margins.bottom = root.parentWindow.barAtBottom ? vClear : 0
            margins.left = pos.x + Theme.margin
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
            color: Qt.alpha(Colors.background, Theme.alphaWindow)

            Column {
                id: overflowColumn
                anchors.top: parent.top
                anchors.topMargin: Theme.margin
                spacing: Theme.margin

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
