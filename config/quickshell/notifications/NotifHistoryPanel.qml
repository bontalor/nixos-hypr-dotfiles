// Notification history panel — opens from the bar button.
//
// Extends the shared theme/Panel scaffold with one section listing all
// entries from `NotifDaemon.history` (newest first). Enter dismisses
// the selected entry from history; Escape closes the panel as usual.
//
// Layout matches the bar's drop-shadow style: bg rect on top of two
// black Rectangles (bottom + right) that produce the visible shadow.

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

    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 0

        Text {
            width: parent.width
            height: Theme.searchRowHeight
            visible: root.historyList.count === 0
            text: "No notifications"
            color: Qt.alpha(Colors.foreground, 0.5)
            font.pixelSize: Theme.fontPixelSize
            font.family: Theme.fontFamily
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            width: parent.width
            height: root.rowHeight
            color: root.inSection && root.selDevice === 0
                   ? Qt.alpha(Colors.base01, Theme.alphaSelected)
                   : "transparent"
            visible: root.historyList.count > 0

            Text {
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                text: "Clear All"
                color: Colors.foreground
                font.pixelSize: Theme.fontPixelSize
                font.family: Theme.fontFamily
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.inSection) { root.inSection = true; root.selDevice = 0 }
                    NotifDaemon.clearHistory()
                }
            }
        }

        Repeater {
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
                color: root.inSection && root.selDevice - 1 === index
                       ? Qt.alpha(Colors.base01, Theme.alphaSelected)
                       : "transparent"

                Column {
                    id: col
                    anchors { left: parent.left; leftMargin: Theme.margin; right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    width: parent.width - 2 * Theme.margin
                    spacing: 4

                    Text {
                        width: parent.width
                        text: summary || "(no summary)"
                        color: Colors.foreground
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: body || ""
                        color: Colors.foreground
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        visible: text !== ""
                    }

                    Item {
                        width: parent.width
                        height: Math.max(appNameLbl.implicitHeight, tsLbl.implicitHeight)

                        Text {
                            id: appNameLbl
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: appName || ""
                            color: Qt.alpha(Colors.foreground, 0.5)
                            font.pixelSize: Theme.fontPixelSizeSmall
                            font.family: Theme.fontFamily
                        }

                        Text {
                            id: tsLbl
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.fmtTimestamp(timestamp)
                            color: Qt.alpha(Colors.foreground, 0.5)
                            font.pixelSize: Theme.fontPixelSizeSmall
                            font.family: Theme.fontFamily
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
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