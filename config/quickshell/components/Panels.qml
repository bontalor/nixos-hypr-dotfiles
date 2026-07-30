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

    // Single source of truth for the keyed set — consumed by the
    // shell.qml `overlay` IPC allowlist (any caller on the IPC bus can
    // invoke the handler, so `name` is matched against this list
    // instead of being passed unchecked to `toggle`, which no-ops
    // silently on unknowns but still busses a free round-trip for
    // untrusted senders). Adding a panel above MUST extend this array;
    // the IPC handler iterates it rather than re-listing the keys.
    readonly property var knownKeys: [
        powerMenu, picker, launcher, volume, network, battery,
        dateTime, weather, media, emoji, notifications, settings,
        clipboard, keybinds, ffmpeg
    ]

    // Launcher-searchable entries, derived from registration.
    property var launcherEntries: []
    property var panels: ({})

    function register(name, panel) {
        var isNew = panels[name] === undefined
        panels[name] = panel
        if (isNew && name !== launcher) {
            var display = panel.title
            if (!display)
                display = name.charAt(0).toUpperCase() + name.slice(1)
            launcherEntries = launcherEntries.concat([{
                name: "Quickshell " + display,
                genericName: "Quickshell Panel",
                panelKey: name
            }])
        }
    }

    // Counterpart to register(): drop the panel from the registry and
    // its launcher entry. Callers that self-register in
    // `Component.onCompleted` should call this from
    // `Component.onDestruction` so reloads that destroy the panel don't
    // leave a stale `panels[name]` reference + dangling launcher entry
    // pointing at a destroyed window. (Panel.qml's FloatingWindow
    // outlives shell reload via keepOnReload so it doesn't need this,
    // but Picker.qml's FloatingWindow does.)
    function unregister(name) {
        if (panels[name] !== undefined) {
            delete panels[name]
            launcherEntries = launcherEntries.filter(function(e) {
                return e.panelKey !== name
            })
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
        // before unmapping the old one. Each in-flight wait owns its
        // own Timer + closure so rapid consecutive toggles (Launcher →
        // Clipboard in <200ms) don't overwrite each other's pending
        // hide state — the previous design shared a single safetyTimer
        // across overlapping toggles, which leaked stale closures onto
        // later-mapping surfaces and silently hid the wrong panel.
        var handled = false
        var safety = null
        const onBackingVisible = () => {
            if (handled || !target.backingWindowVisible) return
            handled = true
            target.backingWindowVisibleChanged.disconnect(onBackingVisible)
            try { safety.stop(); safety.destroy() } catch (e) {}
            // Guard each entry: a shell reload between the toggle
            // (which captured `toHide` by reference) and this
            // deferred run can destroy the captured FloatingWindows,
            // and writing `.visible` on a destroyed window throws,
            // skipping the remaining hides and leaving stale surfaces.
            for (let j = 0; j < toHide.length; j++) {
                if (toHide[j]) toHide[j].visible = false
            }
        }
        target.backingWindowVisibleChanged.connect(onBackingVisible)

        // Safety net: if the surface never maps within 200ms (driver
        // stall, compositor hiccup), unmap the old panels anyway so
        // they don't linger forever. Per-in-flight timer (parented to
        // `target` so it dies with the window) keeps the state isolated
        // from simultaneous toggles — no shared safetyTimer fields are
        // overwritten.
        safety = Qt.createQmlObject(
            'import QtQuick; Timer { interval: 200; repeat: false }',
            target, 'Panels.toggle.safety')
        safety.triggered.connect(() => {
            if (handled) return
            handled = true
            target.backingWindowVisibleChanged.disconnect(onBackingVisible)
            try { safety.destroy() } catch (e) {}
            for (let i = 0; i < toHide.length; i++) {
                if (toHide[i]) toHide[i].visible = false
            }
        })
        safety.start()
    }
}
