pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    property alias special: jsonAdapter.special
    property alias colors: jsonAdapter.colors

    property string background: special.background
    property string foreground: special.foreground
    property string cursor: special.cursor

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
        property string background: "transparent"
        property string foreground: "transparent"
        property string cursor: "transparent"
    }

    component Colors: JsonObject {
        property string color0: "transparent"
        property string color1: "transparent"
        property string color2: "transparent"
        property string color3: "transparent"
        property string color4: "transparent"
        property string color5: "transparent"
        property string color6: "transparent"
        property string color7: "transparent"
        property string color8: "transparent"
        property string color9: "transparent"
        property string color10: "transparent"
        property string color11: "transparent"
        property string color12: "transparent"
        property string color13: "transparent"
        property string color14: "transparent"
        property string color15: "transparent"
    }
}
