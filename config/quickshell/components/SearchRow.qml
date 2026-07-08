// Row wrapper used as the `Repeater.delegate` inside SearchPanel.
// Caller supplies only the row's content children — icon/emoji/text —
// which land in `contentRow.data` via the default property alias. The
// wrapper itself provides:
//   - Standard height (Theme.searchRowHeight)
//   - Selected-background highlight (recomputed against SearchPanel.selectedIndex)
//   - Mouse handler that selects the row and fires SearchPanel.launched()
//
// The SearchPanel reference is read directly off the Repeater's parent
// (`resultCol`), which exposes a `panel` property pointing at the
// SearchPanel root. This avoids a parent-climb that would dead-end at
// the FloatingWindow's ProxyWindowContentItem (whose parent is null).
//
// Inside the Repeater, the engine injects `modelData` and `index` so
// the caller's content can bind to both.

import "../theme"
import Quickshell
import QtQuick

Rectangle {
    id: row
    required property var modelData
    required property int index

    // Read straight from the result Column — populated by SearchPanel.
    property var searchPanel: parent ? parent.panel ?? null : null

    width: parent.width
    height: Theme.searchRowHeight
    color: {
        var panel = row.searchPanel
        if (!panel) return "transparent"
        return row.index === panel.selectedIndex || rowMouse.containsMouse
            ? Qt.alpha(Colors.selected, Theme.alphaSelected)
            : "transparent"
    }

    default property alias content: contentRow.data

    Row {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        spacing: Theme.margin
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (row.searchPanel) row.searchPanel.selectAndLaunch(row.index)
    }
}