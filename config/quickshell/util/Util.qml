pragma Singleton

import QtQuick
import Quickshell
import "../theme"

// Pure-function utilities shared across the shell. No QtQuick item graph,
// no timers, no process state — just functions and a few constants so that
// the various date/calendar/padding snippets stop being copy-pasted.

Singleton {
    // --- Number / string formatting ---

    function ordinal(n) {
        var s = ["th", "st", "nd", "rd"]
        var v = n % 100
        return n + (s[(v - 20) % 10] || s[v] || s[0])
    }

    function zeroPad(n, width) {
        return String(n).padStart(width || 2, "0")
    }

    // --- Calendar helpers ---

    function dayOfYear(d) {
        return Math.floor((d - new Date(d.getFullYear(), 0, 0)) / 86400000)
    }

    function isoWeek(d) {
        var date = new Date(d)
        date.setHours(0, 0, 0, 0)
        date.setDate(date.getDate() + 3 - (date.getDay() + 6) % 7)
        var week1 = new Date(date.getFullYear(), 0, 4)
        return 1 + Math.round(((date - week1) / 86400000 - 3 + (week1.getDay() + 6) % 7) / 7)
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate()
    }

    // 6x7 calendar grid starting on Sunday before the 1st of the month.
    // Returns 42 Date objects once per month — used by DateTimePanel
    // instead of recomputing `new Date(startDay)` per cell per second.
    function monthCells(year, month) {
        var first = new Date(year, month, 1)
        var start = new Date(first)
        start.setDate(start.getDate() - start.getDay())
        var cells = []
        for (var i = 0; i < 42; i++) {
            var d = new Date(start)
            d.setDate(d.getDate() + i)
            cells.push(d)
        }
        return cells
    }

    // --- Time durations ---

    // "1:23", "0:05", "12:34" — mm:ss for media seek bars.
    function fmtSeconds(totalSeconds) {
        var s = Math.max(0, Math.floor(totalSeconds))
        var m = Math.floor(s / 60)
        var ss = s % 60
        return zeroPad(m) + ":" + zeroPad(ss)
    }

    // --- Lunar / moon math ---
    // Synodic (mean) month in days. Constant of the Brown-style algorithm.
    property real _synodicMonth: 29.530587
    property real _lunarEpoch: 2451550.226 // J2000 new-moon epoch (1999-08-29 04:14 UTC)

    // Lunar age (0 .. _synodicMonth) for a given date (UTC). Includes
    // time-of-day for sub-day precision.
    function lunarAge(date) {
        date = date || new Date()
        var y = date.getFullYear()
        var m = date.getMonth() + 1
        var d = date.getDate()
        if (m <= 2) { y -= 1; m += 12 }
        var a = Math.floor(y / 100)
        var b = 2 - a + Math.floor(a / 4)
        var jd = Math.floor(365.25 * (y + 4716))
               + Math.floor(30.6001 * (m + 1))
               + d + b - 1524.5
        jd += date.getHours() / 24 + date.getMinutes() / 1440 + date.getSeconds() / 86400
        var cycles = (jd - _lunarEpoch) / _synodicMonth
        return (cycles - Math.floor(cycles)) * _synodicMonth
    }

    // Phase name from age (days).
    function moonPhaseName(age) {
        if (age < 1.5 || age >= 28.0) return "New Moon"
        if (age < 6.4)  return "Waxing Crescent"
        if (age < 8.4)  return "First Quarter"
        if (age < 13.3) return "Waxing Gibbous"
        if (age < 16.2) return "Full Moon"
        if (age < 21.1) return "Waning Gibbous"
        if (age < 23.1) return "Last Quarter"
        return "Waning Crescent"
    }

    function moonPhaseIcon(name) {
        var p = (name || "").toLowerCase()
        if (p.includes("new"))              return Icon.moonNew
        if (p.includes("waxing crescent")) return Icon.moonWaxingCrescent
        if (p.includes("first quarter"))    return Icon.moonFirstQuarter
        if (p.includes("waxing gibbous"))   return Icon.moonWaxingGibbous
        if (p.includes("full"))             return Icon.moonFull
        if (p.includes("waning gibbous"))   return Icon.moonWaningGibbous
        if (p.includes("last quarter"))     return Icon.moonLastQuarter
        if (p.includes("waning crescent"))   return Icon.moonWaningCrescent
        return ""
    }

    function moonIllumination(age) {
        return Math.round(50 * (1 - Math.cos(2 * Math.PI * age / _synodicMonth)))
    }

    function nextFullMoon(age, fromDate) {
        var daysUntilFull = (14.765 - age + _synodicMonth) % _synodicMonth
        if (daysUntilFull < 0.5) return "Today"
        if (daysUntilFull < 1.5) return "Tomorrow"
        var today = fromDate || new Date()
        var nextFull = new Date(today)
        nextFull.setDate(today.getDate() + Math.round(daysUntilFull))
        return nextFull.getFullYear() + "-"
             + zeroPad(nextFull.getMonth() + 1) + "-"
             + zeroPad(nextFull.getDate())
    }
}