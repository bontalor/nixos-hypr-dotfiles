// Canonical per-row dropdown for actionable list rows.
//
// Used by the panels that don't want to consume the panel-level
// `expandSection` slot (PanelNav already hosts a single expandable
// section per panel — Bluetooth in NetworkPanel, Configuration in
// VolumePanel). The header is supplied by the caller via the default
// slot (so each panel lays out its own labels/bars/icons); this widget
// hosts the toggling MouseArea, the open/close animation geometry, and
// a ConfigProfileRow-styled action list below.
//
// State is panel-owned: binding `isExpanded`/`selActionIndex` from the
// outside keeps keyboard and mouse in sync — the panel tracks
// `expandedRowIdx` and `selRowAction`, resets on section switch and
// panel hide, and intercepts Tab/Enter/J/K/Escape in its onKeyPressed
// override (see NetworkPanel / VolumePanel for the pattern).
//
// Signals:
//   toggled()             header click — caller toggles its expandedRowIdx
//   actionTriggered(idx)  action row click (or keyboard Enter via the
//                         panel's handler)
//
// Caller-side header content is laid out inside `headerItem` (an Item of
// height rowHeight); its children anchor to that Item by `parent.*`.

pragma ComponentBehavior: Bound

import "../theme"
import QtQuick

Item {
    id: root

    property bool isSelected: false       // keyboard-selected row highlight
    property bool isExpanded: false         // dropdown open
    property int selActionIndex: -1        // keyboard-selected action, -1 = none
    property var actions: []               // [{ name: "Mute/Unmute" }, ...]
    property int rowHeight: Theme.rowHeight

    signal toggled()
    signal actionTriggered(int idx)

    width: parent.width
    height: root.rowHeight
            + (root.isExpanded && root.actions.length > 0
               ? root.actions.length * Theme.searchRowHeight
               : 0)

    // Header background — selected-or-hover highlight.
    Rectangle {
        x: 0; y: 0
        width: root.width
        height: root.rowHeight
        color: root.isSelected || headerMouse.containsMouse
               ? Qt.alpha(Colors.selected, Theme.alphaSelected) : "transparent"
    }

    // The header fills exactly rowHeight; children anchor to it via
    // `parent.*` (the default slot forwards them here).
    Item {
        id: headerItem
        x: 0; y: 0
        width: root.width
        height: root.rowHeight
    }

    default property alias headerContent: headerItem.data

    MouseArea {
        id: headerMouse
        x: 0; y: 0
        width: root.width
        height: root.rowHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Column {
        x: 0
        y: root.rowHeight
        width: root.width
        visible: root.isExpanded && root.actions.length > 0

        Repeater {
            model: root.isExpanded ? root.actions : []

            delegate: Rectangle {
                id: actionRect
                required property var modelData
                required property int index
                width: root.width
                height: Theme.searchRowHeight
                color: index === root.selActionIndex
                       ? Qt.alpha(Colors.accent, Theme.alphaSectionHeader)
                       : actHover.containsMouse
                         ? Qt.alpha(Colors.selected, Theme.alphaSelected)
                         : Qt.alpha(Colors.surface, Theme.alphaBackground)

                ThemeText {
                    text: actionRect.modelData.name
                    anchors {
                        left: parent.left; leftMargin: 3 * Theme.margin
                        right: parent.right; rightMargin: Theme.margin
                        verticalCenter: parent.verticalCenter
                    }
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: actHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.actionTriggered(actionRect.index)
                }
            }
        }
    }
}