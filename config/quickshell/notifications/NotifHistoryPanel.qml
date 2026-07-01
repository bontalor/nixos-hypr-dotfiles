// Notification history panel — opens from the bar button.
//
// Extends the shared theme/Panel scaffold with one section listing all
// entries from `NotifDaemon.history` (newest first). Enter dismisses
// the selected entry from history; Escape closes the panel as usual.
//
// Uses custom scrolling (autoScroll: false) because notification entries
// have variable heights — the base Panel's scrollToSelection assumes a
// fixed rowHeight stride.

import "../theme"
import "../util"
import "."
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

Panel {
    id: root
    title: "Notifications"
    sections: [{ name: "History" }]

    autoScroll: false

    property var historyList: NotifDaemon.history

    currentModelLength: function() {
        return root.historyList.count + (root.historyList.count > 0 ? 1 : 0)
    }

    onShown: { /* nothing — history is live */ }

    onDeviceActivated: function(idx) {
        if (idx === 0) {
            NotifDaemon.clearHistory()
        } else if (idx > 0 && idx - 1 < root.historyList.count) {
            NotifDaemon.removeFromHistory(idx - 1)
        }
    }

    onSelDeviceChanged: root.scrollHistoryIntoView()
    onInSectionChanged: if (root.inSection) root.scrollHistoryIntoView()

    // Scroll the Flickable to keep the selected entry visible. Unlike
    // Panel.scrollToSelection (which assumes fixed rowHeight), this reads
    // the actual delegate item's y/height from the Repeater — necessary
    // because notification entries have variable heights.
    function scrollHistoryIntoView() {
        if (!root.inSection) return
        var baseY = historyColumn.y
        if (root.selDevice === 0) {
            // "Clear All" row
            root.scrollToVisible(baseY + clearAllRow.y, clearAllRow.height)
        } else {
            var idx = root.selDevice - 1
            if (idx >= 0 && idx < historyRepeater.count) {
                var item = historyRepeater.itemAt(idx)
                if (item) root.scrollToVisible(baseY + item.y, item.height)
            }
        }
    }

    Column {
        id: historyColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 0

        ThemeText {
            width: parent.width
            height: Theme.searchRowHeight
            visible: root.historyList.count === 0
            text: "No notifications"
            color: Qt.alpha(Colors.foreground, 0.5)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            id: clearAllRow
            width: parent.width
            height: root.rowHeight
            color: (root.inSection && root.selDevice === 0) || clearAllMouse.containsMouse
                   ? Qt.alpha(Colors.base01, Theme.alphaSelected)
                   : "transparent"
            visible: root.historyList.count > 0

            ThemeText {
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                text: "Clear All"
            }

            MouseArea {
                id: clearAllMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.inSection) { root.inSection = true; root.selDevice = 0 }
                    NotifDaemon.clearHistory()
                }
            }
        }

        Repeater {
            id: historyRepeater
            model: root.historyList

            delegate: Rectangle {
                id: entry
                required property string summary
                required property string body
                required property string appName
                required property var timestamp
                required property int index

                width: parent.width
                height: Math.max(root.rowHeight, col.implicitHeight + 2 * Theme.margin)
                color: (root.inSection && root.selDevice - 1 === index) || entryMouse.containsMouse
                       ? Qt.alpha(Colors.base01, Theme.alphaSelected)
                       : "transparent"

                Column {
                    id: col
                    anchors { left: parent.left; leftMargin: Theme.margin; right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    width: parent.width - 2 * Theme.margin
                    spacing: 4

                    ThemeText {
                        width: parent.width
                        text: summary || "(no summary)"
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    ThemeText {
                        width: parent.width
                        text: body || ""
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        visible: text !== ""
                    }

                    Item {
                        width: parent.width
                        height: Math.max(appNameLbl.implicitHeight, tsLbl.implicitHeight)

                        ThemeText {
                            id: appNameLbl
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: appName || ""
                            color: Qt.alpha(Colors.foreground, 0.5)
                            size: "small"
                        }

                        ThemeText {
                            id: tsLbl
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.fmtTimestamp(timestamp)
                            color: Qt.alpha(Colors.foreground, 0.5)
                            size: "small"
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                MouseArea {
                    id: entryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.inSection) { root.inSection = true; root.selDevice = index + 1 }
                        NotifDaemon.removeFromHistory(index)
                    }
                }
            }
        }
    }

    function fmtTimestamp(ms) {
        if (!ms) return ""
        return Qt.formatDateTime(new Date(ms), "h:mm AP")
    }
}
