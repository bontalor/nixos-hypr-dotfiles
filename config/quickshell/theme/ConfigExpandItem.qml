// Expand/collapse config item scaffold used in settings sections.
//
// Shows a labelled header row that toggles an inline sub-list. Callers
// supply the profile rows via the default slot and control expansion state.
//
// Properties:
//   label        — header row text (computed by caller, e.g. "City: Auto")
//   isSelected   — whether this item is keyboard-selected (for highlight)
//   isExpanded   — whether the profile sub-list is currently open
//   profileCount — number of profile rows (drives the height calculation)
//
// Signals:
//   toggled()    — fired when the header row is clicked; caller handles
//                  the expand/collapse state transitions

import "."
import QtQuick

Item {
    id: root
    property string label: ""
    property bool isSelected: false
    property bool isExpanded: false
    property int profileCount: 0

    signal toggled()

    default property alias profiles: profileCol.data

    width: parent.width
    height: isExpanded
            ? Theme.rowHeight + profileCount * Theme.searchRowHeight
            : Theme.rowHeight

    Rectangle {
        anchors.fill: parent
        color: isSelected || headerMouse.containsMouse
               ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
    }

    Column {
        width: parent.width

        Item {
            width: parent.width
            height: Theme.rowHeight

            ThemeText {
                text: root.label
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }

        Column {
            id: profileCol
            width: parent.width
            visible: root.isExpanded
            height: root.isExpanded ? root.profileCount * Theme.searchRowHeight : 0
        }
    }
}
