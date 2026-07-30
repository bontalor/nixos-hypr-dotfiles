pragma ComponentBehavior: Bound

import "../../theme"
import "../../components"
import "../../util"
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: root
    width: trayContent.width
    height: Theme.barHeight

    property var parentWindow

    // Max tray icons shown directly in the bar. Anything beyond this rolls
    // over into the dropdown opened by the chevron on the right.
    readonly property int maxVisible: Theme.trayMaxVisible

    // Inline component declared nested inside the root object — QML
    // 6.x requires inline components to live inside a parent object
    // (a top-level `component` declaration is not supported here,
    // unlike a Qt 6.5+ dialect); the previous nesting was correct.
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
        focusable: visible
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        WlrLayershell.namespace: "quickshell:tray"
        anchors {
            top: !root.parentWindow.barAtBottom
            bottom: root.parentWindow.barAtBottom
            left: true
        }

        margins {
            top: root.parentWindow.barAtBottom ? 0 : Theme.barMargin + Theme.barHeight + Theme.margin
            bottom: root.parentWindow.barAtBottom ? Theme.barMargin + Theme.barHeight + Theme.margin : 0
            // Horizontal offset follows the chevron's x position.
            // Read imperatively on open (see onVisibleChanged) since
            // itemPosition is a function call, not a bindable signal —
            // and re-applied on `trayContent.width`/`parentWindow.width`
            // change so the popup tracks the chevron if the tray
            // rearranges or the bar resizes while the popup is open.
            left: 0
        }

        function reposition() {
            var pos = root.parentWindow.itemPosition(chevronItem)
            margins.left = pos.x + Theme.margin
        }

        onVisibleChanged: if (visible) root.reposition()
        // Keep the popup glued to the chevron while open: icons may
        // appear/disappear (width change), or the bar window itself may
        // resize on screen layout change. Without this, the popup's
        // left margin stays at its on-open value and drifts off the
        // chevron — the previous code only positioned once on open.
        Connections {
            target: trayContent
            function onWidthChanged() { if (overflowPopup.visible) overflowPopup.reposition() }
        }
        Connections {
            target: root.parentWindow
            function onWidthChanged() { if (overflowPopup.visible) overflowPopup.reposition() }
        }

        // As soon as overflow disappears (tray drops to <= maxVisible),
        // dismiss the popup so it doesn't dangle empty with no chevron.
        // Also reposition if the tray rearranges while still overflowing
        // (an icon departing moves the chevron's slot).
        Connections {
            target: SystemTray.items
            function onValuesChanged() {
                if (SystemTray.items.values.length <= root.maxVisible)
                    overflowPopup.visible = false
                else if (overflowPopup.visible)
                    overflowPopup.reposition()
            }
        }

        // Only grab Escape when the popup is actually open and focused —
        // a global Shortcut on a visible:false PanelWindow can shadow
        // Escape handlers elsewhere depending on Quickshell's scoping.
        Shortcut {
            sequence: "Escape"
            enabled: overflowPopup.visible && overflowPopup.activeFocus
            onActivated: overflowPopup.visible = false
        }

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
