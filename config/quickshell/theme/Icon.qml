pragma Singleton

import QtQuick
import Quickshell

// Centralized glyph table. Use `Icon.bolt`, `Icon.plug`, etc. instead
// of scattering "\uf0e7" literals across panels. Includes Nerd Font
// codepoints for power/distro/navigation/transport glyphs, and Unicode
// emoji for moon phases (rendered via the system emoji font).

Singleton {
    // Battery / power profiles
    property string bolt: "\uf0e7"          // performance
    property string balance: "\uf0eb"       // balanced
    property string leaf: "\uf06c"          // power saver
    property string plug: "\uf1e6"          // plugged-in
    property string question: "\uf128"      // unknown profile

    // Distro
    property string distroFallback: "\uf303"

    // Navigation chevrons (SystemTray overflow, Panel marker)
    property string chevronRight: "\u25b6"
    property string chevronLeft: "\u25c0"
    property string chevronUp: "\u25b2"
    property string chevronDown: "\u25bc"
    property string chevronExpand: "\u{f0140}"   // Nerd Font chevron-right-circle
    property string chevronCollapse: "\u{f0143}" // Nerd Font chevron-down-circle

    // Transport (media)
    property string play: chevronRight  // same U+25B6 \u25b6 \u2014 alias to avoid duplicate codepoint
    property string pause: "\u23f8"
    property string prev: "\u23ee"
    property string next: "\u23ed"

    // Volume / brightness
    property string volumeMute: "\uf026"
    property string volumeLow: "\uf027"
    property string volumeHigh: "\uf028"
    property string brightness: "\uDB81\uDDA8"

    // Moon phases (Unicode emoji — see MoonUtil)
    property string moonNew: "\ud83c\udf11"
    property string moonWaxingCrescent: "\ud83c\udf12"
    property string moonFirstQuarter: "\ud83c\udf13"
    property string moonWaxingGibbous: "\ud83c\udf14"
    property string moonFull: "\ud83c\udf15"
    property string moonWaningGibbous: "\ud83c\udf16"
    property string moonLastQuarter: "\ud83c\udf17"
    property string moonWaningCrescent: "\ud83c\udf18"
}
