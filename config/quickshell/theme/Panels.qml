pragma Singleton

import QtQuick
import Quickshell

// In-process panel registry. Replaces the `qs ipc call overlay toggle X`
// self-IPC pattern that spawned a `qs` subprocess per click.
//
// shell.qml registers each overlay panel here in Component.onCompleted:
//     Panels.register("media", mediaPanel)
//
// Any widget or shortcut calls:
//     Panels.toggle("media")
//
// Toggling shows/hides the named panel and hides all others (singleton
// overlay behaviour previously implemented in shell.qml:togglePanel).

Singleton {
    property var panels: ({})

    function register(name, panel) {
        panels[name] = panel
    }

    function toggle(name) {
        for (var key in panels) {
            var p = panels[key]
            if (key === name) p.visible = !p.visible
            else if (p.visible) p.visible = false
        }
    }

    function hideAll() {
        for (var key in panels) {
            var p = panels[key]
            if (p.visible) p.visible = false
        }
    }
}