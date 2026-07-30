pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../util"

Singleton {
    property alias special: jsonAdapter.special
    property alias colors: jsonAdapter.colors

    // Convenience aliases matching common usage. Each guards against an
    // empty adapter value (e.g. a JsonAdapter set to "" by a malformed
    // wal palette file) by falling back to the documented dark default —
    // without this, an empty `background` would silently make every
    // consumer render against "transparent".
    property string background: special.background || "#1e1e2e"
    property string foreground: special.foreground || "#cdd6f4"
    property string cursor: special.cursor || "#f5e0dc"

    // Semantic aliases — name the palette slot by role so consumers
    // don't hardcode palette indices. Same guard pattern: each falls
    // back to its Catppuccin Mocha default if the wal palette slot is
    // missing or empty.
    property string critical: colors.color8 || "#f38ba8"
    property string warning: colors.color9 || "#fab387"
    property string accent: colors.color13 || "#cba6f7"
    property string selected: colors.color1 || "#45475a"
    property string surface: colors.color0 || "#1e1e2e"
    property string border: colors.color5 || "#f5c2e7"
    property string success: colors.color11 || "#a6e3a1"

    FileView {
        path: Paths.walColors
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: jsonAdapter

            readonly property Special special: Special {}
            readonly property ColorsPalette colors: ColorsPalette {}
        }
    }

    component Special: JsonObject {
        // Dark defaults minimize the flash on Quickshell restart (the
        // wal palette loads a few ms after the singleton initialises).
        // Previously all-black, which silently made the bar unreadable
        // (color1=selected on black surface) if pywal's cache was ever
        // removed — a known-good palette keeps the shell legible while
        // reloading and on first run.
        property string background: "#1e1e2e"
        property string foreground: "#cdd6f4"
        property string cursor: "#f5e0dc"
    }

    // Renamed from `component Colors:` to `ColorsPalette` so the
    // inline-component name no longer shadows the file's singleton id
    // `Colors` (registered as the singleton type from Colors.qml) —
    // the previous shadowing was legal but confusing, since `Colors{}`^W
    // could refer to either depending on context.
    component ColorsPalette: JsonObject {
        // Catppuccin Mocha (defaults while the wal cache loads / on a
        // missing palette). The semantic aliases in this singleton
        // (critical=color8, accent=color13, selected=color1, surface=color0,
        // border=color5, success=color11) all stay readable against the
        // dark `background` above.
        property string color0:  "#1e1e2e"   // surface       (selected row bg)
        property string color1:  "#45475a"   // selected      (panel surface)
        property string color2:  "#a6e3a1"
        property string color3:  "#f9e2af"
        property string color4:  "#89b4fa"
        property string color5:  "#f5c2e7"   // border
        property string color6:  "#94e2d5"
        property string color7:  "#bac2de"
        property string color8:  "#f38ba8"   // critical
        property string color9:  "#fab387"   // warning
        property string color10: "#a6e3a1"
        property string color11: "#a6e3a1"   // success
        property string color12: "#89b4fa"
        property string color13: "#cba6f7"   // accent
        property string color14: "#94e2d5"
        property string color15: "#a6adc8"
    }
}
