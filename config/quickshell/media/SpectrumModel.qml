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

    // Application names this shell spawns for sink-monitoring captures
    // (the spectrum FFT helper and the legacy pw-record tail). These
    // are NOT microphone access and must be excluded from the bar's
    // mic-in-use privacy indicator — see bar/widgets/VolumeWidget.qml.
    // Names live here (next to the helper process that uses them) so
    // there's a single source of truth rather than a denylist mirrored
    // in the widget that silently drifts if either side changes.
    readonly property var monitorAppNames: ["Quickshell Peak Detect", "Quickshell Spectrum", "pw-record"]

    // 0..1 per band, bass first. Length Theme.peakBands.
    property var bands: Array(Theme.peakBands).fill(0)

    onActiveChanged: if (!active) bands = Array(Theme.peakBands).fill(0)

    Process {
        running: root.active
        command: ["python3", Quickshell.shellDir + "/media/spectrum.py",
                  String(Theme.peakBands), String(Theme.peakFps)]
        stdout: SplitParser {
            onRead: line => {
                var parts = line.split(";")
                var out = []
                for (var i = 0; i < Theme.peakBands; i++)
                    out.push(Math.min(1, (parseInt(parts[i], 10) || 0) / 100))
                root.bands = out
            }
        }
    }
}
