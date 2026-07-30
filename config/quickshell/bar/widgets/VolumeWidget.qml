import "../../theme"
import "../../components"
import "../../util"
import "../../media"
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

WidgetButton {
    id: root

    // Stored properties so the PwObjectTracker's `objects` binding sees
    // a stable array identity: an inline `[a, b]` literal allocates a
    // fresh array on every underlying re-evaluation (each
    // `defaultAudioSink` change), forcing the tracker to retag/untrack
    // its listeners on every spin. Reading through these properties
    // keeps the array's identity stable across property churn inside
    // the same sink/source pair.
    property var defaultSink: Pipewire.defaultAudioSink
    property var defaultSource: Pipewire.defaultAudioSource
    readonly property var trackedObjects: [root.defaultSink, root.defaultSource]

    PwObjectTracker {
        objects: root.trackedObjects
    }

    property real volume: root.defaultSink?.audio?.volume ?? 0
    property bool muted: root.defaultSink?.audio?.muted ?? false

    // Snapshot of the live audio-in *stream* nodes, recomputed only when
    // `Pipewire.nodes.values` identity changes (a node add/remove).
    // The previous `micInUse` binding re-evaluated the full O(n) scan on
    // every node *property* churn (app open/close, stream start/stop) —
    // a hot path that returned a bool and re-ran the whole loop on each
    // spin. Caching the filtered list here lets `micInUse` itself just
    // walk the small candidate list and re-evaluate only when the set
    // of nodes actually changes.
    readonly property var micStreams: {
        var vals = Pipewire.nodes.values
        var out = []
        for (var i = 0; i < vals.length; i++) {
            var n = vals[i]
            if (n.audio && n.isStream && n.type === PwNodeType.AudioInStream)
                out.push(n)
        }
        return out
    }

    // Mic-in-use privacy indicator: lit while any real capture stream
    // exists. Sink-monitor captures (the visualizer's pw-record,
    // quickshell's own peak monitors) are not microphone access and are
    // excluded via the shared `SpectrumModel.monitorAppNames` denylist
    // — keeping the names next to the helper process that uses them so
    // a rename in one place can't silently let our own monitor count
    // as microphone access.
    readonly property bool micInUse: {
        var deny = SpectrumModel.monitorAppNames
        for (var i = 0; i < root.micStreams.length; i++) {
            var n = root.micStreams[i]
            var p = n.properties
            if (p) {
                var appName = p["application.name"]
                var capSink = p["stream.capture.sink"]
                // `stream.capture.sink` may be a boolean `true` (PipeWire
                // native type) or the string `"true"` depending on the
                // property source — check both.
                if (capSink === true || capSink === "true"
                        || p["media.category"] === "Monitor"
                        || p["stream.monitor"] === "true")
                    continue
                var skip = false
                for (var j = 0; j < deny.length; j++) {
                    if (appName === deny[j]) { skip = true; break }
                }
                if (skip) continue
            }
            return true
        }
        return false
    }

    // Content row instead of `label` so the mic square can sit in the
    // flow, Theme.margin right of the percent text.
    width: contentRow.width + 2 * Theme.margin
    panel: Panels.volume
    acceptRightClick: true

    onRightClicked: mouse => {
        if (Pipewire.defaultAudioSink?.audio)
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
    }

    onWheeled: wheel => {
        if (Pipewire.defaultAudioSink?.audio) {
            var step = Theme.volumeStep
            var newVol = Pipewire.defaultAudioSink.audio.volume + (wheel.angleDelta.y > 0 ? step : -step)
            Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, newVol))
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.margin

        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (!Pipewire.ready) return "Vol ----"
                if (root.muted) return "Vol  Mut"
                return "Vol " + FormatUtil.padNum(Math.round(root.volume * 100), 3) + "%"
            }
        }

        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: "rec"
            color: Colors.foreground
            visible: root.micInUse
        }

        Rectangle {
            width: 4
            height: 4
            anchors.verticalCenter: parent.verticalCenter
            visible: root.micInUse
            color: Colors.foreground
        }
    }
}
