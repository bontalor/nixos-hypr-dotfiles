import "../../theme"
import "../../components"
import "../../util"
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

WidgetButton {
    id: root

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false

    // Mic-in-use privacy indicator: lit while any real capture stream
    // exists. Sink-monitor captures (the visualizer's pw-record,
    // quickshell's own peak monitors) are not microphone access and are
    // excluded.
    readonly property bool micInUse: {
        var vals = Pipewire.nodes.values
        for (var i = 0; i < vals.length; i++) {
            var n = vals[i]
            if (!n.audio || !n.isStream || n.type !== PwNodeType.AudioInStream) continue
            var p = n.properties
            if (p && (p["stream.capture.sink"] === "true"
                      || p["media.category"] === "Monitor"
                      || p["application.name"] === "Quickshell Peak Detect")) continue
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
