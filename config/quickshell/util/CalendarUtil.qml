pragma Singleton

import QtQuick
import Quickshell

// Calendar math helpers. Pure functions, no state. Split out of the
// former Util.qml so date logic has a home separate from formatting and
// astronomy.

Singleton {
    // Milliseconds per day. Used by dayOfYear/isoWeek; lifted to a named
    // constant so the 86400000 magic number stops being copy-pasted.
    property int msPerDay: 86400000

    // Day-of-year (1..366) for a Date.
    function dayOfYear(d) {
        return Math.floor((d - new Date(d.getFullYear(), 0, 0)) / msPerDay)
    }

    // ISO 8601 week number (1..53) for a Date. Standard algorithm:
    // shift to the Thursday of the same ISO week, then count weeks
    // since the year's first Thursday.
    function isoWeek(d) {
        var date = new Date(d)
        date.setHours(0, 0, 0, 0)
        date.setDate(date.getDate() + 3 - (date.getDay() + 6) % 7)
        var week1 = new Date(date.getFullYear(), 0, 4)
        return 1 + Math.round(((date - week1) / msPerDay - 3 + (week1.getDay() + 6) % 7) / 7)
    }

    // Number of days in a given (year, month) where month is 0-based.
    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate()
    }

    // 6x7 calendar grid starting on the week's first day at or before
    // the 1st of the month. `startDay` is a JS getDay() value (0 =
    // Sunday, 1 = Monday — the Settings weekStart pref). Returns 42
    // Date objects once per month — used by DateTimePanel instead of
    // recomputing `new Date(...)` per cell per second.
    function monthCells(year, month, startDay) {
        startDay = startDay || 0
        var first = new Date(year, month, 1)
        var start = new Date(first)
        start.setDate(start.getDate() - ((start.getDay() - startDay + 7) % 7))
        var cells = []
        for (var i = 0; i < 42; i++) {
            var d = new Date(start)
            d.setDate(d.getDate() + i)
            cells.push(d)
        }
        return cells
    }
}
