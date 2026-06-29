// On-screen-display state for volume and screen brightness.
//
// Driven by media keys through the `osd` IpcHandler (see shell.qml):
//   qs ipc call osd volumeUp / volumeDown / mute
//   qs ipc call osd brightnessUp / brightnessDown
//
// Volume is read/written in-process via Pipewire (the same default sink
// the bar widget watches). Brightness shells out to `brightnessctl`,
// since Quickshell 0.3.0 ships no backlight service. Each invocation
// kicks `hideTimer` (5s) — `OsdPopup` mirrors `activeKind` so it shows
// only while the timer is running.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // Currently displayed kind. Empty → hidden.
    property string activeKind: ""  // "" | "volume" | "brightness"
    property real value: 0          // 0..1 progress shown by the bar
    property string glyph: ""       // Nerd Font codepoint shown left
    readonly property bool visible: root.activeKind !== ""

    // Latest known values (kept live so an OSD pop is always fresh).
    property real _brightness: 0
    readonly property real volume: Pipewire.defaultAudioSink?.audio.volume ?? 0
    readonly property bool muted: Pipewire.defaultAudioSink?.audio.muted ?? false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        onTriggered: root.activeKind = ""
    }

    // show controls whether onBrightness pops the OSD. False on
    // startup (cache only); true on every media-key step.
    property bool _show: false

    Process {
        id: brightProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.onBrightness(text)
        }
    }

    Component.onCompleted: root.refreshBrightness()

    // ---- Volume ----

    function volumeUp() {
        var a = Pipewire.defaultAudioSink?.audio
        if (!a) return
        a.muted = false
        a.volume = Math.min(1, a.volume + 0.05)
        root.showVolume()
    }

    function volumeDown() {
        var a = Pipewire.defaultAudioSink?.audio
        if (!a) return
        a.volume = Math.max(0, a.volume - 0.05)
        root.showVolume()
    }

    function volumeMute() {
        var a = Pipewire.defaultAudioSink?.audio
        if (!a) return
        a.muted = !a.muted
        root.showVolume()
    }

    function showVolume() {
        root.activeKind = "volume"
        root.value = root.muted ? 0 : root.volume
        root.glyph = root.volumeGlyph()
        hideTimer.restart()
    }

    function volumeGlyph() {
        if (root.muted) return "\uf026"
        if (root.volume <= 0.33) return "\uf027"
        return "\uf028"
    }

    // ---- Brightness ----

    // brightnessctl writes & reports in one shot so the OSD reflects
    // the actual post-step value rather than a stale guess.
    function brightnessUp() {
        root._show = true
        brightProc.command = ["sh", "-c", "brightnessctl set 5%+ >/dev/null; echo \"$(brightnessctl g) $(brightnessctl m)\""]
        brightProc.running = true
    }

    function brightnessDown() {
        root._show = true
        brightProc.command = ["sh", "-c", "brightnessctl set 5%- >/dev/null; echo \"$(brightnessctl g) $(brightnessctl m)\""]
        brightProc.running = true
    }

    function refreshBrightness() {
        root._show = false
        brightProc.command = ["sh", "-c", "echo \"$(brightnessctl g) $(brightnessctl m)\""]
        brightProc.running = true
    }

    function onBrightness(text) {
        var parts = (text || "").trim().split(/\s+/)
        var cur = parseFloat(parts[0])
        var max = parseFloat(parts[1])
        if (!isFinite(cur) || !isFinite(max) || max <= 0) return
        var v = Math.max(0, Math.min(1, cur / max))
        root._brightness = v
        if (!root._show) return
        root.value = v
        root.glyph = "\uDB81\uDDA8" // U+F05A8 — sun/brightness glyph
        root.activeKind = "brightness"
        hideTimer.restart()
    }
}
