// Themed Text. Defaults color/font/family to the central Theme values so
// the `color: Colors.foreground; font.pixelSize: Theme.fontPixelSize;
// font.family: Theme.fontFamily` triple stops being copy-pasted onto
// every Text in the shell. Callers override only what they need.
//
//   ThemeText { text: "hello"; font.bold: true }
//   ThemeText { text: "small"; size: "small" }

import "../theme"
import "../util"
import QtQuick

Text {
    id: root

    // Size preset — "small" / "normal" / "large". Each maps to a Theme
    // font-pixel-size constant. Defaults to "normal".
    property string size: "normal"

    color: Colors.foreground
    font.capitalization: PrefStore.allLowercase ? Font.AllLowercase : Font.MixedCase
    font.family: Theme.fontFamily
    font.pixelSize: size === "small"
        ? Theme.fontPixelSizeSmall
        : size === "large"
            ? Theme.fontPixelSizeLarge
            : Theme.fontPixelSize
}
