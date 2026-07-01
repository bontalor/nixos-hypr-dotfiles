pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    property alias special: jsonAdapter.special
    property alias colors: jsonAdapter.colors

    // Convenience aliases matching common usage
    property string background: special.background
    property string foreground: special.foreground
    property string cursor: special.cursor

    // Semantic aliases — name the palette slot by role so consumers
    // don't hardcode `base08` for "critical" / `base0d` for "accent".
    property string critical: colors.color8      // base08
    property string warning: colors.color9       // base09
    property string accent: colors.color13        // base0d
    property string selected: colors.color1       // base01

    property string base00: colors.color0
    property string base01: colors.color1
    property string base02: colors.color2
    property string base03: colors.color3
    property string base04: colors.color4
    property string base05: colors.color5
    property string base06: colors.color6
    property string base07: colors.color7
    property string base08: colors.color8
    property string base09: colors.color9
    property string base0a: colors.color10
    property string base0b: colors.color11
    property string base0c: colors.color12
    property string base0d: colors.color13
    property string base0e: colors.color14
    property string base0f: colors.color15

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: jsonAdapter

            readonly property Special special: Special {}
            readonly property Colors colors: Colors {}
        }
    }

    component Special: JsonObject {
        // Dark defaults minimize the flash on Quickshell restart (the
        // wal palette loads a few ms after the singleton initialises).
        // A missing palette is still noticeable — everything is plain
        // black/white with no accent colors.
        property string background: "#000000"
        property string foreground: "#ffffff"
        property string cursor: "#ffffff"
    }

    component Colors: JsonObject {
        property string color0: "#000000"
        property string color1: "#000000"
        property string color2: "#000000"
        property string color3: "#000000"
        property string color4: "#000000"
        property string color5: "#000000"
        property string color6: "#000000"
        property string color7: "#000000"
        property string color8: "#000000"
        property string color9: "#000000"
        property string color10: "#000000"
        property string color11: "#000000"
        property string color12: "#000000"
        property string color13: "#000000"
        property string color14: "#000000"
        property string color15: "#000000"
    }
}
