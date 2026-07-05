pragma Singleton

import QtQuick
import Quickshell

// Centralized glyph table. Use `Icon.bolt`, `Icon.plug`, etc. instead
// of scattering codepoint literals across panels. All entries use the
// \u{...} brace form so any codepoint (BMP or above) is written the
// same way without needing surrogate pairs.

Singleton {
    // Battery / power profiles
    property string bolt:     "\u{f0e7}"   // performance
    property string balance:  "\u{f0eb}"   // balanced
    property string leaf:     "\u{f06c}"   // power saver
    property string plug:     "\u{f1e6}"   // plugged-in
    property string question: "\u{f128}"   // unknown profile

    // Distro
    property string distroFallback: "\u{f303}"

    // Navigation chevrons (SystemTray overflow, Panel marker)
    property string chevronRight:    "\u{25b6}"
    property string chevronLeft:     "\u{25c0}"
    property string chevronUp:       "\u{25b2}"
    property string chevronDown:     "\u{25bc}"
    property string chevronExpand:   "\u{f0140}"
    property string chevronCollapse: "\u{f0143}"

    // Transport (media)
    property string play:  "\u{f040a}"
    property string pause: "\u{f03e4}"
    property string prev:  "\u{f04ae}"
    property string next:  "\u{f04ad}"

    // Volume / brightness
    property string volumeMute: "\u{f026}"
    property string volumeLow:  "\u{f027}"
    property string volumeHigh: "\u{f028}"
    property string brightness: "\u{f05a8}"

    // Microphone (OSD + privacy dot tooltip contexts)
    property string mic:     "\u{f130}"
    property string micMute: "\u{f131}"

    // Notifications (bar do-not-disturb state)
    property string bellMuted: "\u{f1f6}"

    // Generic fault indicator (bar weather chip on fetch failure)
    property string alert: "\u{f0026}"

    // Lockscreen
    property string fingerprint: "\u{F0237}"
}
