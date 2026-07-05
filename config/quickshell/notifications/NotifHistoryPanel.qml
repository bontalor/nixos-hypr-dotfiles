// Notification history panel — opens from the bar button.
//
// Extends the shared components/Panel scaffold with one section listing all
// entries from `NotifDaemon.history` (newest first).
//
// Long entries are truncated (NotifDaemon.notifBodyMaxLines); Tab, Enter, or
// click toggles the selected entry open to its full text (a chevron
// marks entries with more to read), mirroring the VolumePanel
// configuration section: Shift+Tab or Escape collapses first, then
// backs out as usual. The Clear All row is the only way to remove
// entries.
//
// Uses custom scrolling (autoScroll: false) because notification entries
// have variable heights — the base Panel's scrollToSelection assumes a
// fixed rowHeight stride.

import "../theme"
import "../components"
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

    // History index (0-based) of the entry currently expanded to full
    // text, or -1. One entry at a time keeps the list scannable.
    property int expandedIndex: -1

    currentModelLength: function() {
        return root.historyList.count + (root.historyList.count > 0 ? 1 : 0)
    }

    onShown: root.expandedIndex = -1

    function toggleExpand(idx) {
        root.expandedIndex = root.expandedIndex === idx ? -1 : idx
    }

    function clearAll() {
        root.expandedIndex = -1
        NotifDaemon.clearHistory()
    }

    onDeviceActivated: function(idx) {
        if (idx === 0) {
            root.clearAll()
        } else if (idx > 0 && idx - 1 < root.historyList.count) {
            root.toggleExpand(idx - 1)
        }
    }

    // Tab toggles the selected entry's expansion; Shift+Tab and Escape
    // collapse first — the same feel as VolumePanel's config section.
    // Unaccepted keys fall through to Panel's default handler.
    onKeyPressed: function(event) {
        switch (event.key) {
        case Qt.Key_Tab:
            if (event.modifiers & Qt.ShiftModifier) {
                if (root.expandedIndex >= 0) { root.expandedIndex = -1; event.accepted = true }
            } else if (root.inSection && root.selDevice > 0) {
                root.toggleExpand(root.selDevice - 1)
                event.accepted = true
            }
            break
        case Qt.Key_Backtab:
        case Qt.Key_Escape:
            if (root.expandedIndex >= 0) { root.expandedIndex = -1; event.accepted = true }
            break
        }
    }

    onSelDeviceChanged: root.scrollHistoryIntoView()
    onInSectionChanged: if (root.inSection) root.scrollHistoryIntoView()
    // Re-scroll after an expansion settles so the grown entry stays visible.
    onExpandedIndexChanged: Qt.callLater(root.scrollHistoryIntoView)

    // Scroll the Flickable to keep the selected entry visible. Unlike
    // Panel.scrollToSelection (which assumes fixed rowHeight), this reads
    // the actual delegate item's y/height from the Repeater — necessary
    // because notification entries have variable heights.
    function scrollHistoryIntoView() {
        if (!root.inSection) return
        var baseY = historyColumn.y
        if (root.selDevice === 0) {
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

        EmptyLabel {
            visible: root.historyList.count === 0
            text: "No notifications"
        }

        PanelRow {
            id: clearAllRow
            width: parent.width
            height: root.rowHeight
            visible: root.historyList.count > 0
            selected: root.inSection && root.selDevice === 0
            panel: root
            itemIndex: 0
            onClicked: root.clearAll()

            ThemeText {
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                text: "Clear All"
            }
        }

        Repeater {
            id: historyRepeater
            model: root.historyList

            delegate: PanelRow {
                id: entry
                required property string summary
                required property string body
                required property string appName
                required property var timestamp
                required property int index

                property bool expanded: index === root.expandedIndex
                // More to read than the collapsed entry shows?
                property bool expandable: expanded || summaryText.truncated || bodyText.truncated

                width: parent.width
                height: Math.max(root.rowHeight, col.implicitHeight + 2 * Theme.margin)
                selected: root.inSection && root.selDevice - 1 === index
                panel: root
                // History entries sit below the Clear All row in the
                // section's index space.
                itemIndex: index + 1
                onClicked: root.toggleExpand(index)

                Column {
                    id: col
                    anchors { left: parent.left; leftMargin: Theme.margin; right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    width: parent.width - 2 * Theme.margin
                    spacing: 4

                    ThemeText {
                        id: summaryText
                        width: parent.width
                        text: entry.summary || "(no summary)"
                        font.bold: true
                        wrapMode: Text.WordWrap
                        maximumLineCount: entry.expanded ? 9999 : 1
                        elide: Text.ElideRight
                    }

                    ThemeText {
                        id: bodyText
                        width: parent.width
                        text: entry.body || ""
                        wrapMode: Text.WordWrap
                        maximumLineCount: entry.expanded ? 9999 : NotifDaemon.notifBodyMaxLines
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
                            text: entry.appName || ""
                            color: Qt.alpha(Colors.foreground, Theme.alphaDim)
                            size: "small"
                        }

                        ThemeText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            visible: entry.expandable
                            text: entry.expanded ? Icon.chevronCollapse : Icon.chevronExpand
                            color: Qt.alpha(Colors.foreground, Theme.alphaDim)
                            size: "small"
                        }

                        ThemeText {
                            id: tsLbl
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.fmtTimestamp(entry.timestamp)
                            color: Qt.alpha(Colors.foreground, Theme.alphaDim)
                            size: "small"
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }
    }

    // History persists across restarts, so entries can be days old —
    // show the date once it isn't today. Clock format follows the
    // Settings pref like every other time display.
    function fmtTimestamp(ms) {
        if (!ms) return ""
        var d = new Date(ms)
        var t = Qt.formatDateTime(d, PrefStore.timeFormat === "24h" ? "HH:mm" : "h:mm AP")
        var now = new Date()
        var today = d.getDate() === now.getDate()
                 && d.getMonth() === now.getMonth()
                 && d.getFullYear() === now.getFullYear()
        return today ? t : Qt.formatDateTime(d, "MMM d") + ", " + t
    }
}
