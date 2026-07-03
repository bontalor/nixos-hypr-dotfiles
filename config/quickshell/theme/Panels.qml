pragma Singleton

import QtQuick
import Quickshell

// In-process panel registry. Replaces the `qs ipc call overlay toggle X`
// self-IPC pattern that spawned a `qs` subprocess per click.
//
// shell.qml registers each overlay panel here in Component.onCompleted:
//     Panels.register(Panels.media, mediaPanel)
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

    // Launcher-searchable entries, one per user-facing panel. The
    // launcher merges these with desktop applications; genericName makes
    // them all match a "quickshell" or "panel" query.
    readonly property var launcherEntries: [
        { name: "Quickshell Settings",  genericName: "Quickshell Panel", panelKey: settings },
        { name: "Wallpaper Picker",     genericName: "Quickshell Panel", panelKey: picker },
        { name: "Power Menu",           genericName: "Quickshell Panel", panelKey: powerMenu },
        { name: "Volume Panel",         genericName: "Quickshell Panel", panelKey: volume },
        { name: "Network Panel",        genericName: "Quickshell Panel", panelKey: network },
        { name: "Battery & Power Panel", genericName: "Quickshell Panel", panelKey: battery },
        { name: "Date & Time Panel",    genericName: "Quickshell Panel", panelKey: dateTime },
        { name: "Weather Panel",        genericName: "Quickshell Panel", panelKey: weather },
        { name: "Media Panel",          genericName: "Quickshell Panel", panelKey: media },
        { name: "Emoji Picker",         genericName: "Quickshell Panel", panelKey: emoji },
        { name: "Notification History", genericName: "Quickshell Panel", panelKey: notifications }
    ]

    property var panels: ({})

    function register(name, panel) {
        panels[name] = panel
    }

    function toggle(name) {
        Object.keys(panels).forEach(function(key) {
            var p = panels[key]
            if (key === name) p.visible = !p.visible
            else if (p.visible) p.visible = false
        })
    }

    function hideAll() {
        Object.keys(panels).forEach(function(key) {
            var p = panels[key]
            if (p.visible) p.visible = false
        })
    }

}
