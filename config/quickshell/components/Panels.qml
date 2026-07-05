pragma Singleton

import QtQuick
import Quickshell

// In-process panel registry. Replaces the `qs ipc call overlay toggle X`
// self-IPC pattern that spawned a `qs` subprocess per click.
//
// Panels self-register on creation via the window scaffolds' `panelKey`
// property (components/Panel.qml, components/SearchPanel.qml, wallpaper/Picker.qml):
//     MediaPanel { panelKey: Panels.media }
//
// Any widget or shortcut calls:
//     Panels.toggle(Panels.media)
//
// Toggling shows/hides the named panel and hides all others.
//
// Named string constants (Panels.media, Panels.launcher, …) replace the
// raw string keys that were hardcoded in ~12 places — a typo in a magic
// string silently failed; a typo in a constant is a compile-time error.

Singleton {
    // --- Named panel keys (use these instead of raw strings) ---
    readonly property string none: ""
    readonly property string powerMenu: "powermenu"
    readonly property string picker: "picker"
    readonly property string launcher: "launcher"
    readonly property string volume: "volume"
    readonly property string network: "network"
    readonly property string battery: "battery"
    readonly property string dateTime: "datetime"
    readonly property string weather: "weather"
    readonly property string media: "media"
    readonly property string emoji: "emoji"
    readonly property string notifications: "notifications"
    readonly property string settings: "settings"
    readonly property string clipboard: "clipboard"
    readonly property string keybinds: "keybinds"

    // Launcher-searchable entries, derived from registration (one per
    // user-facing panel, named by the panel's window title). The
    // launcher merges these with desktop applications; genericName makes
    // them all match a "quickshell" or "panel" query. The launcher
    // itself is skipped — searching for yourself in yourself is noise.
    property var launcherEntries: []

    property var panels: ({})

    function register(name, panel) {
        var isNew = panels[name] === undefined
        panels[name] = panel
        if (isNew && name !== launcher) {
            launcherEntries = launcherEntries.concat([{
                name: panel.title,
                genericName: "Quickshell Panel",
                panelKey: name
            }])
        }
    }

    function toggle(name) {
        Object.keys(panels).forEach(function(key) {
            var p = panels[key]
            if (key === name) p.visible = !p.visible
            else if (p.visible) p.visible = false
        })
    }

}
