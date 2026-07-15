pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../theme"
import "../util"

// On-screen-display state singleton for volume + brightness. Driven via
// the `osd` IpcHandler in shell.qml. Volume read/written in-process
// through Pipewire; brightness shells out to `brightnessctl` (Quickshell
// 0.3.0 ships no backlight service). Maintains activeKind/value/glyph
// and a hide timer (hideInterval) that OsdPopup mirrors.

Singleton {
    id: root

    property int hideInterval: 3000
    property int brightnessStep: 5           // percent per key press
    // Floor so `brightnessDown` can never blank the panel by driving the
    // backlight to 0% (brightnessctl allows 0 by default, which on most
    // laptops turns the panel off entirely — a footgun if the user
    // instinctively mashes the down key).
    property int brightnessMin: 1
    // Volume fraction below which the "low" glyph is shown.
    property real volumeGlyphThreshold: 0.5

    property string activeKind: ""    // "volume" | "brightness"
    property real value: 0
    property string glyph: ""
    property bool visible: false

    // Pipewire volume state. `?? 0`/`?? false` guards against
    // defaultAudioSink being null at startup.
    property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }


    property bool _show: false   // true when a media-key step should pop the OSD

    Timer {
        id: hideTimer
        interval: root.hideInterval
        repeat: false
        onTriggered: root.visible = false
    }

    // Single shared Process for brightnessctl commands. Reused across
    // up/down/refresh; command is rebound per call. Reentrancy is
    // guarded by Process's restart-on-running semantics.
    CheckedProcess {
        id: brightProc
        label: "brightnessctl"
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.onBrightness(text)
        }
    }

    function volumeUp() {
        var sink = Pipewire.defaultAudioSink
        if (sink && sink.audio) {
            sink.audio.volume = Math.min(1, sink.audio.volume + Theme.volumeStep)
            showVolume()
        }
    }

    function volumeDown() {
        var sink = Pipewire.defaultAudioSink
        if (sink && sink.audio) {
            sink.audio.volume = Math.max(0, sink.audio.volume - Theme.volumeStep)
            showVolume()
        }
    }

    function volumeMute() {
        var sink = Pipewire.defaultAudioSink
        if (sink && sink.audio) {
            sink.audio.muted = !sink.audio.muted
            showVolume()
        }
    }

    function showVolume() {
        root.activeKind = "volume"
        root.value = root.muted ? 0 : root.volume
        root.glyph = root.volumeGlyph()
        root.visible = true
        hideTimer.restart()
    }

    function volumeGlyph() {
        if (root.muted) return Icon.volumeMute
        if (root.volume < root.volumeGlyphThreshold) return Icon.volumeLow
        return Icon.volumeHigh
    }

    function micMute() {
        var src = Pipewire.defaultAudioSource
        if (src && src.audio) {
            src.audio.muted = !src.audio.muted
            root.activeKind = "mic"
            root.value = src.audio.muted ? 0 : (src.audio.volume ?? 0)
            root.glyph = src.audio.muted ? Icon.micMute : Icon.mic
            root.visible = true
            hideTimer.restart()
        }
    }

    function brightnessUp() {
        brightProc.command = ["brightnessctl", "s", "+" + root.brightnessStep + "%"]
        brightProc.running = true
    }

    // OsdModel.value caches the current brightness (0..1) parsed from
    // the last refresh. Suppress a down step that would land below
    // brightnessMin so the panel can't go pitch-black from a blind
    // brightness-down mash (a real footgun — `brightnessctl s N%-`
    // reduces by N% of *current*, eventually arriving at <1%, which
    // reads as black on most panels).
    function brightnessDown() {
        var pct = Math.round(root.value * 100)
        if (pct <= root.brightnessMin) return  // already at or below the floor
        // Would the step underflow? Set the floor directly rather than
        // overshoot to a screen-blanking 0%.
        if (pct - root.brightnessStep < root.brightnessMin)
            brightProc.command = ["brightnessctl", "s", String(root.brightnessMin) + "%"]
        else
            brightProc.command = ["brightnessctl", "s", root.brightnessStep + "%-"]
        brightProc.running = true
    }

    function refreshBrightness() {
        brightProc.command = ["brightnessctl", "info"]
        brightProc.running = true
    }

    function onBrightness(text) {
        // Parse "cur max" percentages from `brightnessctl info`/`set`.
        var m = text.match(/\((\d+)%\)/)
        var pct = m ? parseInt(m[1]) / 100 : 0
        if (!isFinite(pct) || pct <= 0) {
            // Initial read may fail if brightnessctl isn't ready yet —
            // still re-enable _show so future key presses work.
            if (!root._show) root._show = true
            return
        }
        if (root._show) {
            root.activeKind = "brightness"
            root.value = pct
            root.glyph = Icon.brightness
            root.visible = true
            hideTimer.restart()
        } else {
            // Initial silent read (from Component.onCompleted) — cache
            // the value, re-enable _show, but don't pop the OSD.
            root._show = true
        }
    }

    Component.onCompleted: {
        // Prime the brightness cache silently (no OSD pop on startup).
        // _show is re-enabled inside onBrightness after this initial
        // read completes — setting it here would race the async process
        // and cause a spurious OSD pop on restart.
        root._show = false
        refreshBrightness()
    }
}
