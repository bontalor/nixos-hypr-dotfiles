// Shared profile sub-row for expandable-config sections — the indented
// rows inside a ConfigExpandItem. Provides the standard searchRowHeight,
// the selected/hover/base background triple, and the indented label that
// were previously duplicated across VolumePanel and WeatherPanel.
//
// Extra content (e.g. WeatherPanel's inline city TextInput) lands in the
// default slot. The MouseArea sits on top of slot content, matching the
// original rows — slot children are driven by keyboard focus, not clicks.

import "."
import QtQuick

Rectangle {
    id: root

    property string label: ""
    // Keyboard selection (caller compares against selConfigProfile).
    property bool isSelected: false

    signal clicked()

    default property alias content: slot.data

    width: parent.width
    height: Theme.searchRowHeight
    color: isSelected
           ? Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)
           : rowMouse.containsMouse
               ? Qt.alpha(Colors.base01, Theme.alphaSelected)
               : Qt.alpha(Colors.base00, Theme.alphaBackground)

    ThemeText {
        visible: root.label !== ""
        text: root.label
        anchors {
            left: parent.left; leftMargin: 3 * Theme.margin
            right: parent.right; rightMargin: Theme.margin
            verticalCenter: parent.verticalCenter
        }
        elide: Text.ElideRight
    }

    Item {
        id: slot
        anchors.fill: parent
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
