import "../theme"
import "../components"
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

    // Month shown in the calendar, as an offset from the current month.
    // Paged from the month-selector level (or the header chevrons);
    // reopening the panel or switching sections snaps back to today.
    property int monthOffset: 0

    // Two-level Calendar navigation. Entering the section lands on the
    // month selector (inMonthGrid false): the header row is highlighted
    // and H/L page months. Enter/Tab descend into the month grid, where
    // H/L move by day and J/K by week; Shift+Tab climbs back out one
    // level at a time (grid -> selector -> sidebar).
    property bool inMonthGrid: false

    onShown: { root.monthOffset = 0; root.inMonthGrid = false }
    onSectionChanged: { root.monthOffset = 0; root.inMonthGrid = false }

    // Land on today when it's the displayed month, else on the 1st.
    function enterMonthGrid() {
        root.inMonthGrid = true
        for (var i = 0; i < root.cellDates.length; i++) {
            var d = root.cellDates[i]
            var hit = root.monthOffset === 0
                ? (d.getDate() === root.now.getDate()
                   && d.getMonth() === root.now.getMonth()
                   && d.getFullYear() === root.now.getFullYear())
                : (d.getDate() === 1 && d.getMonth() === root._month)
            if (hit) { root.selDevice = i; return }
        }
        root.selDevice = 0
    }

    // Precompute once per month so the calendar grid doesn't re-allocate
    // 42 Date objects on every second tick. _totalMonths is integer
    // arithmetic, so the 1Hz `now` tick never produces a new value (and
    // never re-runs monthCells) until the month or offset changes.
    property int _totalMonths: now.getFullYear() * 12 + now.getMonth() + monthOffset
    property int _year: Math.floor(_totalMonths / 12)
    property int _month: ((_totalMonths % 12) + 12) % 12
    // First weekday follows the Settings pref (getDay() convention).
    readonly property int weekStartDay: PrefStore.weekStart === "monday" ? 1 : 0
    readonly property var weekdayNames: {
        var names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return names.slice(root.weekStartDay).concat(names.slice(0, root.weekStartDay))
    }
    property var cellDates: CalendarUtil.monthCells(_year, _month, weekStartDay)
    property int isoWeek: CalendarUtil.isoWeek(now)
    property int doy: CalendarUtil.dayOfYear(now)

    // Pre-empts Panel's default handler for both calendar levels; keys
    // left unaccepted (e.g. plain Tab in the grid) fall through to it.
    onKeyPressed: function(event) {
        if (root.selSection !== 2 || !root.inSection) return
        var shift = event.modifiers & Qt.ShiftModifier

        if (!root.inMonthGrid) {
            switch (event.key) {
            case Qt.Key_H:
            case Qt.Key_Left:
                root.monthOffset--
                event.accepted = true; break
            case Qt.Key_L:
            case Qt.Key_Right:
                root.monthOffset++
                event.accepted = true; break
            case Qt.Key_J:
            case Qt.Key_Down:
            case Qt.Key_K:
            case Qt.Key_Up:
                // The selector is the only row at this level.
                event.accepted = true; break
            case Qt.Key_Tab:
                if (shift) root.inSection = false
                else root.enterMonthGrid()
                event.accepted = true; break
            case Qt.Key_Backtab:
                root.inSection = false
                event.accepted = true; break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.enterMonthGrid()
                event.accepted = true; break
            }
            return
        }

        switch (event.key) {
        case Qt.Key_H:
        case Qt.Key_Left:
            root.selDevice = Scroll.step(root.selDevice, -1, 42)
            event.accepted = true; break
        case Qt.Key_L:
        case Qt.Key_Right:
            root.selDevice = Scroll.step(root.selDevice, 1, 42)
            event.accepted = true; break
        case Qt.Key_J:
        case Qt.Key_Down:
            root.selDevice = Scroll.clamp(root.selDevice + 7, 0, 41)
            event.accepted = true; break
        case Qt.Key_K:
        case Qt.Key_Up:
            root.selDevice = Scroll.clamp(root.selDevice - 7, 0, 41)
            event.accepted = true; break
        case Qt.Key_Tab:
            if (shift) { root.inMonthGrid = false; event.accepted = true }
            break
        case Qt.Key_Backtab:
        case Qt.Key_Escape:
            root.inMonthGrid = false
            event.accepted = true; break
        }
    }

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
    onInMonthGridChanged: root.calendarScroll()
    onInSectionChanged: {
        root.inMonthGrid = false
        if (root.inSection) root.calendarScroll()
    }

    function calendarScroll() {
        if (!root.inSection || root.selSection !== 2) return
        if (!root.inMonthGrid) {
            // Selector level: keep the month header in view.
            root.scrollToVisible(0, root.headerHeight)
            return
        }
        // Rows above the grid: section header bar, month header,
        // weekday header — each headerHeight + colSpacing.
        var y = 3 * (root.headerHeight + root.colSpacing)
              + Math.floor(root.selDevice / 7) * root.cellHeight
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
                    text: Qt.formatDateTime(root.now, "dddd, ") + FormatUtil.ordinal(root.now.getDate()) + Qt.formatDateTime(root.now, " 'of' MMMM, yyyy")
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

        // Month header: [ ‹ ] [ March 2026 ] [ › ]
        // Three independent buttons, each with its own hover background.
        // Clicking the month label toggles between day-grid and month-selector.
        Row {
            id: calHeader
            width: parent.width
            height: Theme.headerHeight
            spacing: Theme.margin

            Rectangle {
                width: Theme.headerHeight
                height: Theme.headerHeight
                color: prevHov.containsMouse
                       ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
                ThemeText {
                    anchors.centerIn: parent
                    text: Icon.chevronLeft
                }
                MouseArea {
                    id: prevHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.monthOffset--
                }
            }

            Rectangle {
                width: calHeader.width - 2 * Theme.headerHeight - 2 * Theme.margin
                height: Theme.headerHeight
                color: monthHov.containsMouse || (root.inSection && !root.inMonthGrid)
                       ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
                ThemeText {
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(new Date(root._year, root._month, 1), "MMMM yyyy")
                    font.bold: true
                }
                MouseArea {
                    id: monthHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selSection = 2
                        root.inSection = true
                        if (root.inMonthGrid) root.inMonthGrid = false
                        else root.enterMonthGrid()
                    }
                }
            }

            Rectangle {
                width: Theme.headerHeight
                height: Theme.headerHeight
                color: nextHov.containsMouse
                       ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
                ThemeText {
                    anchors.centerIn: parent
                    text: Icon.chevronRight
                }
                MouseArea {
                    id: nextHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.monthOffset++
                }
            }
        }

        Item {
            width: parent.width
            height: Theme.headerHeight

            Row {
                anchors { left: parent.left; right: parent.right }
                spacing: 0

                Repeater {
                    model: root.weekdayNames

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
                        if ((root.inSection && root.inMonthGrid && root.selDevice === index) || cellMouse.containsMouse)
                            return Qt.alpha(Colors.base01, Theme.alphaSelected)
                        // Compare against the real today, not the
                        // displayed month — offset months would
                        // otherwise highlight their same-numbered day.
                        var today = modelData.getDate() === root.now.getDate()
                                 && modelData.getMonth() === root.now.getMonth()
                                 && modelData.getFullYear() === root.now.getFullYear()
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
                            root.inMonthGrid = true
                            root.selDevice = index
                            root.forceFocus()
                        }
                    }
                }
            }
        }
    }
}
