//@ pragma UseQApplication

import "./wallpaper"
import "./launcher"
import "./power"
import "./network"
import "./volume"
import "./time"
import "./weather"
import "./media"
import "./bar"
import "./emoji"
import Quickshell
import Quickshell.Io

Scope {
    Bar{}
    Notifications{}

    property var panels: [
        { key: "powermenu", panel: powerMenu },
        { key: "picker", panel: picker },
        { key: "launcher", panel: launcher },
        { key: "volume", panel: volumePanel },
        { key: "network", panel: networkPanel },
        { key: "battery", panel: batteryPanel },
        { key: "datetime", panel: dateTimePanel },
        { key: "weather", panel: weatherPanel },
        { key: "media", panel: mediaPanel },
        { key: "emoji", panel: emojiPicker }
    ]

    Picker { id: picker }
    Launcher { id: launcher }
    PowerMenu { id: powerMenu }
    VolumePanel { id: volumePanel }
    NetworkPanel { id: networkPanel }
    BatteryPanel { id: batteryPanel }
    DateTimePanel { id: dateTimePanel }
    WeatherPanel { id: weatherPanel }
    MediaPanel { id: mediaPanel }
    EmojiPicker { id: emojiPicker }

    function togglePanel(name) {
        for (var i = 0; i < panels.length; i++) {
            var entry = panels[i]
            entry.panel.visible = (entry.key === name) ? !entry.panel.visible : false
        }
    }

    IpcHandler {
        target: "overlay"
        enabled: true
        function toggle(name: string): void {
            togglePanel(name)
        }
    }
}
