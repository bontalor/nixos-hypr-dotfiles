pragma Singleton

import QtQuick
import Quickshell
import "../theme"  // FormatUtil

// Lunar / moon-phase math. Pure functions over a small set of constants.
// Split out of the former Util.qml so astronomy has a home separate from
// formatting and calendar math.
//
// Exposes:
//   - lunarAge(date)          phase age (0 .. synodicMonth) for a Date
//   - moonPhaseName(age)      "New Moon" / "Waxing Crescent" / etc.
//   - moonPhaseIcon(name)     Nerd Font / emoji glyph matching the name
//   - moonIllumination(age)   0..100 percent illuminated
//   - nextFullMoon(age, from) human-readable date of the next full moon

Singleton {
    // Moon phase emoji (Unicode). Kept here alongside the phase logic that
    // uses them rather than in Icon.qml, which holds shell-wide glyphs.
    readonly property string moonNew:             "🌑"
    readonly property string moonWaxingCrescent:  "🌒"
    readonly property string moonFirstQuarter:    "🌓"
    readonly property string moonWaxingGibbous:   "🌔"
    readonly property string moonFull:            "🌕"
    readonly property string moonWaningGibbous:   "🌖"
    readonly property string moonLastQuarter:     "🌗"
    readonly property string moonWaningCrescent:  "🌘"

    // Synodic (mean) month in days. Constant of the Brown-style algorithm.
    property real synodicMonth: 29.530587
    // J2000 new-moon epoch (1999-08-29 04:14 UTC).
    property real lunarEpoch: 2451550.226

    // Lunar age (0 .. synodicMonth) for a given date (UTC). Includes
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
        var cycles = (jd - lunarEpoch) / synodicMonth
        return (cycles - Math.floor(cycles)) * synodicMonth
    }

    // Phase name from age (days). Thresholds approximate the quarter
    // boundaries (synodicMonth/8 increments) tuned for the canonical
    // eight-phase naming scheme.
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

    // Icon glyph matching moonPhaseName's return value. Derives from name
    // so callers can't drift between the two.
    function moonPhaseIcon(name) {
        var p = (name || "").toLowerCase()
        if (p.includes("new"))             return moonNew
        if (p.includes("waxing crescent")) return moonWaxingCrescent
        if (p.includes("first quarter"))   return moonFirstQuarter
        if (p.includes("waxing gibbous"))  return moonWaxingGibbous
        if (p.includes("full"))            return moonFull
        if (p.includes("waning gibbous"))  return moonWaningGibbous
        if (p.includes("last quarter"))    return moonLastQuarter
        if (p.includes("waning crescent")) return moonWaningCrescent
        return ""
    }

    // Illuminated percentage of the moon's visible disk (0..100).
    function moonIllumination(age) {
        return Math.round(50 * (1 - Math.cos(2 * Math.PI * age / synodicMonth)))
    }

    // Human-readable date of the next full moon. Half a synodic month
    // ahead of the current age, rounded to the nearest day.
    function nextFullMoon(age, fromDate) {
        var daysUntilFull = (synodicMonth / 2 - age + synodicMonth) % synodicMonth
        if (daysUntilFull < 0.5) return "Today"
        if (daysUntilFull < 1.5) return "Tomorrow"
        var today = fromDate || new Date()
        var nextFull = new Date(today)
        nextFull.setDate(today.getDate() + Math.round(daysUntilFull))
        return nextFull.getFullYear() + "-"
             + FormatUtil.zeroPad(nextFull.getMonth() + 1) + "-"
             + FormatUtil.zeroPad(nextFull.getDate())
    }
}
