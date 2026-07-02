pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../util"
import "../theme"

// Real audio spectrum for the bar media visualizer. media/spectrum.py
// captures the default sink's monitor via pw-record and FFT-bins it
// into Theme.peakBands log-spaced bands tiling 40 Hz - 16 kHz (see the
// script for DSP and latency details), printing one "v0;v1;..." line
// of ints 0-100 per frame at Theme.peakFps. One shared helper process
// feeds every bar instance; it only runs while something is playing.

Singleton {
    id: root

    readonly property bool active: MprisSelector.currentPlayer?.playbackState === MprisPlaybackState.Playing

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
