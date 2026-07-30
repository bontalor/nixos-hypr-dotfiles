// Expand/collapse config item scaffold used in settings sections.
//
// Shows a labelled header row that toggles an inline sub-list. Callers
// supply the profile rows via the default slot and control expansion state.
//
// Properties:
//   label        — header row text (computed by caller, e.g. "City: Auto")
//   sublabel     — optional dimmed second line (e.g. the active profile)
//   isSelected   — whether this item is keyboard-selected (for highlight)
//   isExpanded   — whether the profile sub-list is currently open
//   profileCount — number of profile rows (drives the height calculation)
//   panel        — the owning Panel; when set, a header click runs the
//                  standard panel.toggleConfigItem(itemIndex) transition
//   itemIndex    — this item's index in the config section
//
// Signals:
//   toggled()    — fired when the header row is clicked, after the
//                  standard transition (for caller side effects)

pragma ComponentBehavior: Bound

import "."
import "../theme"
import QtQuick

Item {
    id: root
    property string label: ""
    property string sublabel: ""
    property bool isSelected: false
    property bool isExpanded: false
    property int profileCount: 0
    // Typed as Panel so tooling/parse-time check catches typos in
    // `toggleConfigItem`/`sectionSubs` (the call site reads
    // `panel.toggleConfigItem(itemIndex)`). `Panel` is the components/
    // Panel.qml type — `import "."` above makes it visible.
    property Panel panel: null
    property int itemIndex: 0

    signal toggled()

    default property alias profiles: profileCol.data

    width: parent.width
    height: isExpanded
            ? Theme.rowHeight + profileCount * Theme.searchRowHeight
            : Theme.rowHeight

    Rectangle {
        anchors.fill: parent
        color: root.isSelected || headerMouse.containsMouse
               ? Qt.alpha(Colors.selected, Theme.alphaSelected) : "transparent"
    }

    Column {
        width: parent.width

        Item {
            width: parent.width
            height: Theme.rowHeight

            ThemeText {
                text: root.label
                anchors {
                    left: parent.left; leftMargin: Theme.margin
                    right: parent.right; rightMargin: Theme.margin
                }
                y: root.sublabel === ""
                   ? (parent.height - height) / 2
                   : Theme.margin
                elide: Text.ElideRight
            }

            ThemeText {
                visible: root.sublabel !== ""
                text: root.sublabel
                anchors {
                    left: parent.left; leftMargin: Theme.margin
                    right: parent.right; rightMargin: Theme.margin
                    top: parent.top; topMargin: Theme.rowHeight * 0.5
                }
                color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                elide: Text.ElideRight
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.panel) root.panel.toggleConfigItem(root.itemIndex)
                    root.toggled()
                }
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
