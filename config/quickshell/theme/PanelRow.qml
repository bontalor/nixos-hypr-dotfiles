// Shared scaffold for selectable panel rows.
//
// Provides the standard highlight-on-selected-or-hover Rectangle and a
// MouseArea that emits clicked(). Content children land in the default
// slot and are rendered on top of the hover layer so child MouseAreas
// (e.g. a mute button) still receive events normally.
//
// Usage:
//   PanelRow {
//       width: parent.width
//       height: root.rowHeight
//       selected: root.inSection && index === root.selDevice
//       onClicked: { ... }
//       ThemeText { ... }
//   }

import "."
import QtQuick

Rectangle {
    id: row
    property bool selected: false
    signal clicked()

    default property alias content: contentItem.data

    color: selected || hoverArea.containsMouse
           ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
