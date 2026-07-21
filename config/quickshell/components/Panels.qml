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
    readonly property string ffmpeg: "ffmpeg"

    // Launcher-searchable entries, derived from registration.
    property var launcherEntries: []
    property var panels: ({})

    function register(name, panel) {
        var isNew = panels[name] === undefined
        panels[name] = panel
        if (isNew && name !== launcher) {
            launcherEntries = launcherEntries.concat([{
                name: "Quickshell " + panel.title,
                genericName: "Quickshell Panel",
                panelKey: name
            }])
        }
    }

    function toggle(name) {
        var target = panels[name]
        if (!target) return

        // Toggling the already-visible panel hides it.
        if (target.visible) {
            target.visible = false
            return
        }

        // Collect outgoing panels. Show the *new* one first, then hide
        // the old one — but only after the new surface is actually
        // mapped (backingWindowVisible = true), otherwise the
        // compositor renders a blank frame between unmap and map,
        // which the user sees as a flicker. backingWindowVisible is
        // QsWindow's readonly "the compositor acknowledges this
        // surface" state (see Quickshell docs); visible is just the
        // request. We listen on backingWindowVisibleChanged, fire
        // once, and detach.
        var toHide = []
        Object.keys(panels).forEach(key => {
            if (key !== name && panels[key].visible) toHide.push(panels[key])
        })

        target.visible = true

        // If nothing was open, there's nothing to clean up.
        if (toHide.length === 0) return

        // If the new panel is already backing-visible (e.g. it was
        // shown very recently and the surface is still mapped), hide
        // the old ones immediately.
        if (target.backingWindowVisible) {
            for (var i = 0; i < toHide.length; i++) toHide[i].visible = false
            return
        }

        // Otherwise wait for the compositor to map the new surface
        // before unmapping the old one.
        const onBackingVisible = () => {
            if (target.backingWindowVisible) {
                target.backingWindowVisibleChanged.disconnect(onBackingVisible)
                for (let j = 0; j < toHide.length; j++) toHide[j].visible = false
            }
        }
        target.backingWindowVisibleChanged.connect(onBackingVisible)

        // Safety net: if the surface never maps within 200ms (driver
        // stall, compositor hiccup), unmap the old panels anyway so
        // they don't linger forever.
        safetyTimer.toHide = toHide
        safetyTimer.target = target
        safetyTimer.slot = onBackingVisible
        safetyTimer.restart()
    }

    Timer {
        id: safetyTimer
        interval: 200
        repeat: false
        property var toHide: []
        property var target: null
        property var slot: null
        onTriggered: {
            if (target && slot) {
                try { target.backingWindowVisibleChanged.disconnect(slot) } catch (e) {}
            }
            for (let i = 0; i < toHide.length; i++) toHide[i].visible = false
            toHide = []
            target = null
            slot = null
        }
    }
}
