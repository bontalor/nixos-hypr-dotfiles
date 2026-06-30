pragma Singleton

import QtQuick
import Quickshell

// Number / string formatting helpers. Pure functions, no QtQuick item
// graph, no state. Split out of the former Util.qml junk drawer so the
// various formatting snippets stop being copy-pasted.

Singleton {
    // 1 -> "1st", 2 -> "2nd", 3 -> "3rd", 11 -> "11th", 21 -> "21st".
    // The (v - 20) shift maps 11/12/13 (which must be "th") into the
    // zero/th/nd/rd table slot for their last digit.
    function ordinal(n) {
        var s = ["th", "st", "nd", "rd"]
        var v = n % 100
        return n + (s[(v - 20) % 10] || s[v] || s[0])
    }

    // zeroPad(5, 3) -> "005". Defaults to 2-digit zero-padding.
    function zeroPad(n, width) {
        return String(n).padStart(width || 2, "0")
    }

    // fmtSeconds(83) -> "01:23". mm:ss for media seek bars. Clamps negative.
    function fmtSeconds(totalSeconds) {
        var s = Math.max(0, Math.floor(totalSeconds))
        var m = Math.floor(s / 60)
        var ss = s % 60
        return zeroPad(m) + ":" + zeroPad(ss)
    }

    // Right-pad a number to a fixed width with leading spaces so the
    // digits align in a monospace bar. padNum(5, 3) -> "  5".
    function padNum(n, width) {
        return String(n).padStart(width || 3, " ")
    }
}
