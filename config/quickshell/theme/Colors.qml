pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../util"

Singleton {
    property alias special: jsonAdapter.special
    property alias colors: jsonAdapter.colors

    // Convenience aliases matching common usage
    property string background: special.background
    property string foreground: special.foreground
    property string cursor: special.cursor

    // Semantic aliases — name the palette slot by role so consumers
    // don't hardcode palette indices.
    property string critical: colors.color8
    property string warning: colors.color9
    property string accent: colors.color13
    property string selected: colors.color1
    property string surface: colors.color0
    property string border: colors.color5
    property string success: colors.color11

    FileView {
        path: Paths.walColors
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
