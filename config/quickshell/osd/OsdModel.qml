pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../theme"

// On-screen-display state singleton for volume + brightness. Driven via
// the `osd` IpcHandler in shell.qml. Volume read/written in-process
// through Pipewire; brightness shells out to `brightnessctl` (Quickshell
// 0.3.0 ships no backlight service). Maintains activeKind/value/glyph
// and a hide timer that OsdPopup mirrors.
//
// The hide timer interval is Theme.osdHideInterval (3s).

Singleton {
    id: root

    property string activeKind: ""    // "volume" | "brightness"
    property real value: 0
    property string glyph: ""
    property bool visible: false

    // Pipewire volume state. `?? 0`/`?? false` guards against
    // defaultAudioSink being null at startup.
    property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }


    property bool _show: false   // true when a media-key step should pop the OSD

    Timer {
        id: hideTimer
        interval: Theme.osdHideInterval
        repeat: false
        onTriggered: root.visible = false
    }

    // Single shared Process for brightnessctl commands. Reused across
    // up/down/refresh; command is rebound per call. Reentrancy is
    // guarded by Process's restart-on-running semantics.
    Process {
        id: brightProc
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
        if (root.volume < Theme.volumeGlyphThreshold) return Icon.volumeLow
        return Icon.volumeHigh
    }

    function brightnessUp() {
        brightProc.command = ["brightnessctl", "s", "+" + Theme.brightnessStep + "%"]
        brightProc.running = true
    }

    function brightnessDown() {
        brightProc.command = ["brightnessctl", "s", Theme.brightnessStep + "%-"]
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
