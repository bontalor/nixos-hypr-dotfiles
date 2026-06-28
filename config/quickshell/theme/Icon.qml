pragma Singleton

import QtQuick
import Quickshell

// Centralized Nerd Font glyph table. Use `Icon.bolt`, `Icon.plug`, etc.
// instead of scattering "\uf0e7" literals across panels.

Singleton {
    // Battery / power profiles
    property string bolt: "\uf0e7"          // performance
    property string balance: "\uf0eb"       // balanced
    property string leaf: "\uf06c"          // power saver
    property string plug: "\uf1e6"          // plugged-in
    property string question: "\uf128"      // unknown profile

    // Distro
    property string distroFallback: "\uf303"

    // Navigation chevron
    property string chevronRight: "\u25b6"
    property string play: "\u25b6"
    property string prev: "\u23ee"
    property string next: "\u23ed"
    property string pause: "\u23f8"

    // Moon phases (see Weather.MoonModel)
    property string moonNew: "\ud83c\udf11"
    property string moonWaxingCrescent: "\ud83c\udf12"
    property string moonFirstQuarter: "\ud83c\udf13"
    property string moonWaxingGibbous: "\ud83c\udf14"
    property string moonFull: "\ud83c\udf15"
    property string moonWaningGibbous: "\ud83c\udf16"
    property string moonLastQuarter: "\ud83c\udf17"
    property string moonWaningCrescent: "\ud83c\udf18"
}