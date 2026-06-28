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
import "./theme"
import "./models"
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    Bar{}
    Notifications{}

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

    Component.onCompleted: {
        Panels.register("powermenu", powerMenu)
        Panels.register("picker", picker)
        Panels.register("launcher", launcher)
        Panels.register("volume", volumePanel)
        Panels.register("network", networkPanel)
        Panels.register("battery", batteryPanel)
        Panels.register("datetime", dateTimePanel)
        Panels.register("weather", weatherPanel)
        Panels.register("media", mediaPanel)
        Panels.register("emoji", emojiPicker)
    }

    IpcHandler {
        target: "overlay"
        enabled: true
        function toggle(name: string): void {
            Panels.toggle(name)
        }
    }
}
