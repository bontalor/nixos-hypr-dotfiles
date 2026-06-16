import "../../theme"
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root
    width: volText.width + 20
    height: 30

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property real volume: Pipewire.defaultAudioSink?.audio.volume ?? 0
    property bool muted: Pipewire.defaultAudioSink?.audio.muted ?? false

    Process {
        id: ipcToggle
        command: ["qs", "ipc", "call", "overlay", "toggle", "volume"]
        running: false
    }

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? Qt.alpha(Colors.base08, 0.75) : "transparent"
    }

    Text {
        id: volText
        anchors.centerIn: parent
        text: {
            if (!Pipewire.ready) return "Vol ----"
            if (root.muted) return "Vol  Mut"
            return "Vol " + ("  " + Math.round(root.volume * 100)).slice(-3) + "%"
        }
        font.pixelSize: 16
        font.family: "JetBrainsMono Nerd Font"
        color: Colors.foreground
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (Pipewire.defaultAudioSink?.audio) {
                    Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                }
            } else {
                ipcToggle.running = true
            }
        }
        onWheel: (wheel) => {
            if (Pipewire.defaultAudioSink?.audio) {
                var step = 0.05
                var newVol = Pipewire.defaultAudioSink.audio.volume + (wheel.angleDelta.y > 0 ? step : -step)
                Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, newVol))
            }
        }
    }
}
