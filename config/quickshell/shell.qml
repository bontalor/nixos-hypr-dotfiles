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
import "./notifications"
import "./osd"
import "./theme"
import "./models"
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    Bar{}
    Notifications{}
    NotifPopup{}
    OsdPopup{}

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
    NotifHistoryPanel { id: notifHistoryPanel }

    Component.onCompleted: {
        Panels.register(Panels.powerMenu, powerMenu)
        Panels.register(Panels.picker, picker)
        Panels.register(Panels.launcher, launcher)
        Panels.register(Panels.volume, volumePanel)
        Panels.register(Panels.network, networkPanel)
        Panels.register(Panels.battery, batteryPanel)
        Panels.register(Panels.dateTime, dateTimePanel)
        Panels.register(Panels.weather, weatherPanel)
        Panels.register(Panels.media, mediaPanel)
        Panels.register(Panels.emoji, emojiPicker)
        Panels.register(Panels.notifications, notifHistoryPanel)
    }

    IpcHandler {
        target: "overlay"
        enabled: true
        function toggle(name: string): void {
            Panels.toggle(name)
        }
    }

    IpcHandler {
        target: "osd"
        enabled: true
        function volumeUp(): void { OsdModel.volumeUp() }
        function volumeDown(): void { OsdModel.volumeDown() }
        function mute(): void { OsdModel.volumeMute() }
        function brightnessUp(): void { OsdModel.brightnessUp() }
        function brightnessDown(): void { OsdModel.brightnessDown() }
    }
}
