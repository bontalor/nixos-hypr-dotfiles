pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../util"
import "../theme"

// Real audio spectrum for the bar media visualizer. media/spectrum.py
// captures the default sink's monitor via pw-record and FFT-bins it
// into Theme.peakBands log-spaced bands tiling 50 Hz - 16 kHz (see the
// script for DSP and latency details), printing one "v0;v1;..." line
// of ints 0-100 per frame at Theme.peakFps. One shared helper process
// feeds every bar instance; it only runs while something is playing.

Singleton {
    id: root

    // Gated on the Settings visualizer pref — when off, the helper
    // process never runs and bands stay zeroed.
    readonly property bool active: PrefStore.visualizer
        && MprisSelector.currentPlayer?.playbackState === MprisPlaybackState.Playing

    // 0..1 per band, bass first. Length Theme.peakBands.
    property var bands: Array(Theme.peakBands).fill(0)

    // Debounce `active` so a transient MPRIS player swap (disconnect
    // then reconnect in <100ms) doesn't tear down the python + pw-record
    // stream and immediately respawn it — full FFT re-init and a
    // PipeWire quantum renegotiation each time. The 100ms window
    // collapses brief gaps without visible lag (the bar visualizer
    // already has 250ms granularity in the panel timer).
    property bool _activeDebounced: false
    Timer {
        id: activeDebounce
        interval: 100
        onTriggered: {
            root._activeDebounced = root.active
            if (!root._activeDebounced) root.bands = Array(Theme.peakBands).fill(0)
        }
    }
    onActiveChanged: activeDebounce.restart()
    Component.onCompleted: root._activeDebounced = root.active

    Process {
        running: root._activeDebounced
        command: ["python3", Quickshell.shellDir + "/media/spectrum.py",
                  String(Theme.peakBands), String(Theme.peakFps)]
        stdout: SplitParser {
            onRead: line => {
                var parts = line.split(";")
                // Skip malformed frames (partial lines from pw-record
                // mid-write EOF at teardown) — without this, `parts[i]`
                // is undefined for missing fields, `parseInt(undefined)`
                // is NaN → 0, padding the right bands to zero and
                // causing a visible "right bars drop" flash on stop.
                if (parts.length < Theme.peakBands) return
                var out = []
                for (var i = 0; i < Theme.peakBands; i++)
                    out.push(Math.min(1, (parseInt(parts[i], 10) || 0) / 100))
                root.bands = out
            }
        }
    }
}
