import "../../theme"
import "../../util"
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

WidgetButton {
    id: root

    width: volText.width + 2 * Theme.margin

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false

    label: {
        if (!Pipewire.ready) return "Vol ----"
        if (root.muted) return "Vol  Mut"
        return "Vol " + FormatUtil.padNum(Math.round(root.volume * 100), 3) + "%"
    }
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

    // Hidden text for width measurement (WidgetButton owns the visible label).
    Text {
        id: volText
        visible: false
        text: root.label
        font.pixelSize: Theme.fontPixelSize
        font.family: Theme.fontFamily
    }
}
