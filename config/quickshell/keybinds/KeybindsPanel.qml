// Keybind cheatsheet — lists the compositor's live bind table from
// `hyprctl binds -j`, refreshed on every open (a one-shot shell-out of
// the same class as pw-dump: no Quickshell/Hyprland API exposes binds).
// Searchable by key combo or by dispatcher/description; Enter or click
// just closes the panel — the rows are reference, not actions.

import "../theme"
import "../components"
import QtQuick
import Quickshell
import Quickshell.Io

SearchPanel {
    id: root
    title: "Keybinds"

    property var binds: []

    onVisibleChanged: if (visible) bindsProc.running = true

    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.binds = root.parseBinds(text)
        }
    }

    // Hyprland modmask uses X11 modifier bits.
    function modString(mask) {
        var mods = []
        if (mask & 64) mods.push("SUPER")
        if (mask & 8) mods.push("ALT")
        if (mask & 4) mods.push("CTRL")
        if (mask & 1) mods.push("SHIFT")
        return mods.join("+")
    }

    function parseBinds(text) {
        var data
        try { data = JSON.parse(text) } catch (e) { return [] }
        var out = []
        for (var i = 0; i < data.length; i++) {
            var b = data[i]
            var mods = modString(b.modmask)
            // Lua-registered binds report dispatcher "__lua" and an
            // opaque callback id — useless to display. Their real label
            // comes from the bind's description (hl.bind supports a
            // `description` option; lor-shell.lua sets it on its binds).
            var action = b.description
                || (b.dispatcher === "__lua" ? "lua action (no description)"
                                             : b.dispatcher + (b.arg ? " " + b.arg : ""))
            out.push({
                name: (mods ? mods + "+" : "") + (b.key || "code:" + b.keycode),
                action: action
            })
        }
        return out
    }

    items: root.binds
    matchPredicate: function(item, q) {
        return item.name.toLowerCase().includes(q)
            || item.action.toLowerCase().includes(q)
    }

    // Distinguish a failed/empty `hyprctl binds` read from no search hits.
    emptyText: root.binds.length === 0
        ? "No binds reported — is `hyprctl binds -j` available?"
        : "No matches"

    onLaunched: root.visible = false

    rowDelegate: SearchRow {
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData?.name ?? ""
            width: 240
            elide: Text.ElideRight
        }
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData?.action ?? ""
            color: Qt.alpha(Colors.foreground, Theme.alphaDim)
            width: Theme.panelWidth - 240 - 8 * Theme.margin
            elide: Text.ElideRight
        }
    }
}
