// Search-list panel scaffold shared by Launcher, EmojiPicker, and
// PowerMenu. Each of those previously reimplemented the same ~200 lines
// of FloatingWindow + search TextInput + Flickable + scroll helper +
// keyboard nav + visibility reset.
//
// Caller supplies:
//   property var       items          raw list (each row expected to have
//                                      at least `.name` unless matchPredicate
//                                      is overridden)
//   property int       maxLength      cap filtered results (0 = unlimited;
//                                      EmojiPicker uses 10)
//   property var       matchPredicate function(item, q) -> bool
//                                      defaults to substring match on `item.name`
//   property Component rowDelegate     the SearchRow (with content children)
//                                      that the Repeater instantiates
//   signal             launched(int idx)   fires on Enter or row click

import "."
import "../util"
import Quickshell
import QtQuick

FloatingWindow {
    id: root
    title: ""
    color: "transparent"
    implicitWidth: Theme.panelWidth
    implicitHeight: Theme.panelHeight
    visible: false
    onClosed: visible = false

    // --- Caller-supplied state ----------------------------------------------
    property var items: []
    property int maxLength: 0
    property var matchPredicate: function(item, q) {
        return item && item.name && item.name.toLowerCase().includes(q)
    }
    property Component rowDelegate

    signal launched(int idx)

    // --- Internal state -----------------------------------------------------
    property int selectedIndex: 0
    property string query: searchText.text.trim().toLowerCase()

    property var filtered: {
        var all = root.items || []
        var list = all
        if (root.query !== "") {
            var q = root.query
            list = []
            for (var i = 0; i < all.length; i++) {
                if (root.matchPredicate(all[i], q)) list.push(all[i])
            }
            list = FuzzySort.sort(q, list)
        }
        if (root.maxLength > 0 && list.length > root.maxLength) {
            list = list.slice(0, root.maxLength)
        }
        return list
    }

    onVisibleChanged: if (visible) {
        searchText.text = ""
        root.selectedIndex = 0
        searchText.forceActiveFocus()
    }
    onSelectedIndexChanged: if (resultFlick) resultFlick.scrollToSelected()

    function launchSelected() {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.filtered.length)
            root.launched(root.selectedIndex)
    }

    function selectAndLaunch(idx) {
        root.selectedIndex = idx
        root.launchSelected()
    }

    // --- Layout -------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Column {
            anchors.fill: parent
            anchors.margins: Theme.margin
            spacing: Theme.margin

            Rectangle {
                width: parent.width
                height: Theme.searchRowHeight
                color: Qt.alpha(Colors.base00, Theme.alphaBackground)
                clip: true

                TextInput {
                    id: searchText
                    anchors {
                        left: parent.left; leftMargin: Theme.margin
                        right: parent.right; rightMargin: Theme.margin
                        verticalCenter: parent.verticalCenter
                    }
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    onTextChanged: root.selectedIndex = 0

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Down:
                            root.selectedIndex = Math.min(root.selectedIndex + 1, Math.max(0, root.filtered.length - 1))
                            event.accepted = true; break
                        case Qt.Key_Up:
                            root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                            event.accepted = true; break
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            root.launchSelected()
                            event.accepted = true; break
                        case Qt.Key_Escape:
                            root.visible = false
                            event.accepted = true; break
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: parent.height - Theme.searchRowHeight - Theme.margin
                color: Qt.alpha(Colors.base00, Theme.alphaBackground)

                Flickable {
                    id: resultFlick
                    anchors.fill: parent
                    anchors.margins: Theme.margin
                    contentHeight: resultCol.height
                    clip: true

                    function scrollToSelected() {
                        // y of row N = N * (rowHeight + colSpacing).
                        // Note: resultFlick is inset by Theme.margin inside
                        // its surrounding panel Rectangle, so a 0px gap from
                        // the Flickable edge reads as Theme.margin against
                        // the visible panel background.
                        var y = root.selectedIndex * (Theme.searchRowHeight + Theme.margin)
                        var h = Theme.searchRowHeight
                        var viewH = resultFlick.height
                        var maxY = Math.max(0, resultCol.height - viewH)
                        if (y < resultFlick.contentY) {
                            resultFlick.contentY = Math.max(0, y)
                        } else if (y + h > resultFlick.contentY + viewH) {
                            resultFlick.contentY = Math.min(maxY, y + h - viewH)
                        }
                    }

                    Column {
                        id: resultCol
                        width: parent.width
                        spacing: Theme.margin
                        // Expose the SearchPanel root to delegate instances.
                        // The FloatingWindow root isn't reachable from the
                        // delegate via parent climb (it sits behind a
                        // ProxyWindowContentItem whose parent is null),
                        // so delegates can read `parent.panel` directly.
                        property var panel: root

                        Repeater {
                            id: resultRepeater
                            model: root.filtered
                            delegate: root.rowDelegate
                        }
                    }
                }
            }
        }
    }
}