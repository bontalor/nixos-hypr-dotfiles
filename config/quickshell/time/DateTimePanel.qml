import "../theme"
import "../util"
import QtQuick
import Quickshell
import Quickshell.Io

Panel {
    id: root
    title: "Date & Time"
    sections: [
        { name: "Date" },
        { name: "Time" },
        { name: "Calendar" }
    ]

    autoScroll: false


    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    property var now: clock.date

    // Precompute once per month so the calendar grid doesn't re-allocate
    // 42 Date objects on every second tick. Only `now`'s month/year
    // gate this binding — the rest of the panel clock ticks at 1Hz but
    // these arrays stay frozen.
    property int _year: now.getFullYear()
    property int _month: now.getMonth()
    property var cellDates: CalendarUtil.monthCells(_year, _month)
    property int isoWeek: CalendarUtil.isoWeek(now)
    property int doy: CalendarUtil.dayOfYear(now)

    property string timezoneString: {
        var name = Qt.formatDateTime(root.now, "t")
        var offset = Qt.formatDateTime(root.now, "tt")
        if (name) return name + " (UTC" + offset + ")"
        return "UTC" + offset
    }

    // Calendar cell height tracks the grid width so scroll-to-selected
    // stays correct if the panel is resized (previously hardcoded 36).
    readonly property real cellHeight: calendarGrid.width / 7

    currentModelLength: function() { return root.selSection === 2 ? 42 : 0 }

    onSelDeviceChanged: root.calendarScroll()
    onInSectionChanged: if (root.inSection) root.calendarScroll()

    function calendarScroll() {
        if (!root.inSection || root.selSection !== 2) return
        var y = root.headerHeight + root.colSpacing + Math.floor(root.selDevice / 7) * root.cellHeight
        root.scrollToVisible(y, root.cellHeight)
    }

    // ---- Section 0: Date ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 0

        Item {
            width: parent.width
            height: Theme.headerHeight * 3 + 20

            Column {
                anchors.fill: parent
                spacing: Theme.margin

                ThemeText {
                    text: Qt.formatDateTime(root.now, "dddd, MMMM d, yyyy")
                }

                ThemeText {
                    text: "Day of year: " + root.doy
                    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                }

                ThemeText {
                    text: "Week: " + root.isoWeek
                    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                }
            }
        }
    }

    // ---- Section 1: Time ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 1

        Item {
            width: parent.width
            height: Theme.headerHeight * 3 + 20

            Column {
                anchors.fill: parent
                spacing: Theme.margin

                ThemeText {
                    text: Qt.formatDateTime(root.now, PrefStore.timeFormat === "24h" ? "HH:mm:ss" : "h:mm:ss AP")
                    font.pixelSize: 24
                    font.bold: true
                }

                ThemeText {
                    text: "Timezone: " + root.timezoneString
                    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                }

                ThemeText {
                    text: "UTC: " + root.now.toUTCString()
                    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                }
            }
        }
    }

    // ---- Section 2: Calendar ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 2

        Item {
            width: parent.width
            height: Theme.headerHeight

            Row {
                anchors { left: parent.left; right: parent.right }
                spacing: 0

                Repeater {
                    model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

                    delegate: ThemeText {
                        width: parent.width / 7
                        height: Theme.headerHeight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                    }
                }
            }
        }

        Grid {
            id: calendarGrid
            width: parent.width
            columns: 7
            spacing: 0

            Repeater {
                model: root.cellDates

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: calendarGrid.width / 7
                    height: root.cellHeight
                    color: {
                        if ((root.inSection && root.selDevice === index) || cellMouse.containsMouse)
                            return Qt.alpha(Colors.base01, Theme.alphaSelected)
                        var today = modelData.getDate() === root.now.getDate()
                                 && modelData.getMonth() === root._month
                                 && modelData.getFullYear() === root._year
                        if (today) return Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)
                        return "transparent"
                    }

                    ThemeText {
                        anchors.centerIn: parent
                        text: modelData.getDate()
                        color: modelData.getMonth() !== root._month
                               ? Qt.alpha(Colors.foreground, Theme.alphaBackground)
                               : Colors.foreground
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selSection = 2
                            root.inSection = true
                            root.selDevice = index
                            root.forceFocus()
                        }
                    }
                }
            }
        }
    }
}
