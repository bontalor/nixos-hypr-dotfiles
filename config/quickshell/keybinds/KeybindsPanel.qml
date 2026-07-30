// Keybind cheatsheet — lists the compositor's live bind table from
// `hyprctl binds -j`, refreshed on every open (a one-shot shell-out of
// the same class as pw-dump: no Quickshell/Hyprland API exposes binds).
// Searchable by key combo or by dispatcher/description; Enter or click
// just closes the panel — the rows are reference, not actions.

pragma ComponentBehavior: Bound

import "../theme"
import "../components"
import QtQuick
import Quickshell
import Quickshell.Io

SearchPanel {
    id: root
    title: "Keybinds"

    property var binds: []

    onVisibleChanged: if (visible) {
        // Reset to the empty state immediately so a stale result from a
        // prior open doesn't linger while the new fetch is in flight;
        // then re-fetch only if the prior `hyprctl binds` has finished
        // (setting `running = true` on an already-running Process is a
        // no-op and would silently show the stale output until the next
        // open). Killing the prior proc first would also work but
        // re-launching once it exits (via `running = false` then `true`)
        // would race the StdioCollector's `onStreamFinished`; simplest
        // is to drop the result if we can't start a fresh fetch now.
        root.binds = []
        if (!bindsProc.running) bindsProc.running = true
    }

    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: if (root.visible) root.binds = root.parseBinds(text)
        }
    }

    // Hyprland's modmask uses X11 modifier bits. Named constants below
    // keep the table self-documenting — the raw `64 / 8 / 4 / 1` literals
    // were brittle to compare against `Qt.ShiftModifier` etc. (the Qt
    // enums differ in value), so any future reader would have to
    // cross-reference hyprctl's source.
    readonly property int _modSuper:  64
    readonly property int _modAlt:    8
    readonly property int _modCtrl:   4
    readonly property int _modShift:  1

    function modString(mask) {
        var mods = []
        if (mask & root._modSuper)  mods.push("SUPER")
        if (mask & root._modAlt)    mods.push("ALT")
        if (mask & root._modCtrl)   mods.push("CTRL")
        if (mask & root._modShift)  mods.push("SHIFT")
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
        id: keybindRow
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: keybindRow.modelData?.name ?? ""
            width: Theme.keybindKeyColumnWidth
            elide: Text.ElideRight
        }
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: keybindRow.modelData?.action ?? ""
            color: Qt.alpha(Colors.foreground, Theme.alphaDim)
            width: Theme.panelWidth - Theme.keybindKeyColumnWidth - 8 * Theme.margin
            elide: Text.ElideRight
        }
    }
}
