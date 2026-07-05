// Shared scaffold for selectable panel rows.
//
// Provides the standard highlight-on-selected-or-hover Rectangle and a
// MouseArea that emits clicked(). Content children land in the default
// slot and are rendered on top of the hover layer so child MouseAreas
// (e.g. a mute button) still receive events normally.
//
// When `panel` is set, a click on a row outside the section first
// performs the standard enter-section selection (inSection = true,
// selDevice = itemIndex) before clicked() fires — the same transition
// the keyboard flow uses, previously hand-rolled in every onClicked.
//
// Usage:
//   PanelRow {
//       width: parent.width
//       height: root.rowHeight
//       selected: root.inSection && index === root.selDevice
//       panel: root
//       itemIndex: index
//       onClicked: { ... }
//       ThemeText { ... }
//   }

import "."
import "../theme"
import QtQuick

Rectangle {
    id: row
    property bool selected: false
    property var panel: null
    property int itemIndex: 0
    signal clicked()

    default property alias content: contentItem.data

    color: selected || hoverArea.containsMouse
           ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (row.panel && !row.panel.inSection) {
                row.panel.inSection = true
                row.panel.selDevice = row.itemIndex
            }
            row.clicked()
        }
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
