// Themed Text. Defaults color/font/family to the central Theme values so
// the `color: Colors.foreground; font.pixelSize: Theme.fontPixelSize;
// font.family: Theme.fontFamily` triple stops being copy-pasted onto
// every Text in the shell. Callers override only what they need.
//
//   ThemeText { text: "hello"; font.bold: true }
//   ThemeText { text: Icon.play; font.pixelSize: 24 }   // icons render via Theme.iconFamily
//
// Icon glyph routing: when the bound text contains a Nerd Font glyph
// (see Icon.isIconText), `font.family` swaps to `Theme.iconFamily`
// (a Nerd Font) instead of `Theme.fontFamily` (the user's main font).
// That keeps every Icon.* glyph rendering at proper Nerd-Font geometry
// even when the user has retargeted `Theme.fontFamily` to a non-nerd
// typeface via Settings. Substituting Qt's fontconfig fallback for the
// real Nerd font matters for sizing/metrics consistency and on systems
// without any Nerd Font installed (the user's pref matches what they
// typed, but icons still need their own dedicated face).

import "../theme"
import "../util"
import QtQuick

Text {
    id: root

    // Size preset — "small" / "normal" / "large". Each maps to a Theme
    // font-pixel-size constant. Defaults to "normal".
    property string size: "normal"

    // Cache the per-char scan once per text change so re-evaluations
    // triggered by other property reads (font.capitalization below
    // responding to PrefStore.allLowercase, for instance) don't
    // re-walk the string.
    readonly property bool _isIcon: Icon.isIconText(root.text)

    color: Colors.foreground
    font.capitalization: PrefStore.allLowercase ? Font.AllLowercase : Font.MixedCase
    font.family: root._isIcon ? Theme.iconFamily : Theme.fontFamily
    font.pixelSize: size === "small"
        ? Theme.fontPixelSizeSmall
        : size === "large"
            ? Theme.fontPixelSizeLarge
            : Theme.fontPixelSize
}
