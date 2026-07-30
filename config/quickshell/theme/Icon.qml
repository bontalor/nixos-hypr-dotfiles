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

    // Classify a Text string as "contains a Nerd Font glyph" so ThemeText
    // can route it through `Theme.iconFamily` (a Nerd Font) regardless of
    // `Theme.fontFamily`. Without this, a user who sets a non-nerd main
    // font (Inter, Cantarell, Noto Sans, …) gets Icon.* glyphs from Qt's
    // fontconfig substitution list — which may or may not exist on
    // their box, and is at best the wrong size/metrics. Forcing the icon
    // face keeps every Icon.* glyph at consistent Nerd-Font geometry.
    //
    // Nerd Font glyphs live in two PUA ranges:
    //   U+E000  .. U+F8FF  — BMP Private Use Area. The bulk of the
    //                         Font Awesome / Material / devicons packs.
    //   U+F0001 .. U+FFFFD — Plane 15 Supplementary PUA-B + Nerd Font
    //                         Brand glyphs (`Icon.play/prev/next`,
    //                         `Icon.chevronExpand/…`, `Icon.fingerprint`).
    // Plane-15 codepoints show up in UTF-16 as a surrogate pair with the
    // high surrogate in [0xDB80 .. 0xDBBF] (derivation:
    //   H = 0xD800 + ((cp-0x10000) >> 10); PUA-B maps to exactly that
    //   range). charCodeAt() reads raw UTF-16 units, so the regex below
    //   catches both ranges in a single scan.
    // Returns true only when the string is made up *entirely* of Nerd
    // can route it through `Theme.iconFamily` (a Nerd Font) regardless of
    // `Theme.fontFamily`. Without this, a user who sets a non-nerd main
    // font (Inter, Cantarell, Noto Sans, …) gets Icon.* glyphs from Qt's
    // fontconfig substitution list — which may or may not exist on
    // their box, and is at best the wrong size/metrics. Forcing the icon
    // face keeps every Icon.* glyph at consistent Nerd-Font geometry.
    //
    // Nerd Font glyphs live in two PUA ranges:
    //   U+E000  .. U+F8FF  — BMP Private Use Area. The bulk of the
    //                         Font Awesome / Material / devicons packs.
    //   U+F0001 .. U+FFFFD — Plane 15 Supplementary PUA-B + Nerd Font
    //                         Brand glyphs (`Icon.play/prev/next`,
    //                         `Icon.chevronExpand/…`, `Icon.fingerprint`).
    // Plane-15 codepoints show up in UTF-16 as a surrogate pair with the
    // high surrogate in [0xDB80 .. 0xDBBF] (derivation:
    //   H = 0xD800 + ((cp-0x10000) >> 10); PUA-B maps to exactly that
    //   range). charCodeAt() reads raw UTF-16 units, so the regex below
    //   catches both ranges in a single scan.
    // Returns true only when the string is made up *entirely* of Nerd
    // Font glyphs (and whitespace) — so ThemeText can route the whole
    // label through `Theme.iconFamily` (a Nerd Font) and get consistent
    // icon geometry. The previous "any glyph" predicate returned true
    // for mixed labels like `Icon.play + "  Mute"`: the whole string
    // then got rendered in Nerd Font, which doesn't carry the regular
    // "Mute" letters — they showed as tofu (□). Mixed labels are now
    // left on `Theme.fontFamily` so Qt's font fallback chain sniffs
    // each glyph from the right font.
    function isIconText(s) {
        if (!s) return false
        var hasIcon = false
        for (var i = 0; i < s.length; i++) {
            var c = s.charCodeAt(i)
            var isIcon = (c >= 0xE000 && c <= 0xF8FF) || (c >= 0xDB80 && c <= 0xDBBF)
            if (isIcon) {
                hasIcon = true
                // Plane-15 PUA glyphs project to the 0xDB80..0xDBBF high
                // surrogate range; their low half (0xDC00..0xDFFF) is the
                // next UTF-16 unit. Skip it — without this, the low half
                // fails both the PUA range check and the whitespace test
                // below, so the function returns false for any Plane-15
                // glyph (Icon.play/pause/prev/next/chevronExpand/…/
                // fingerprint/brightness) and ThemeText falls back to
                // the user's non-nerd font, rendering tofu on systems
                // without a Nerd Font in Qt's fallback chain.
                if (c >= 0xD800 && c <= 0xDBFF) i++
                continue
            }
            // Allow whitespace only — any "real" non-icon glyph (or a
            // non-PUA surrogate pair's low half that reached here)
            // disqualifies the label from Nerd Font routing.
            var ch = s.charAt(i)
            if (!/\s/.test(ch)) return false
        }
        return hasIcon
    }
}
