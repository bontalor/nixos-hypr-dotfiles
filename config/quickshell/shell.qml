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
import "./clipboard"
import "./keybinds"
import "./ffmpeg"
import "./notifications"
import "./settings"
import "./osd"
import "./components"
import "./models"
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Bar{}
    ReloadNotif{}
    NotifPopup{}
    OsdPopup{}
    BatteryAlerts{}

    // Each panel self-registers with the Panels registry via panelKey
    // (see components/Panel.qml) — one declaration per panel, no separate
    // registration list to keep in sync.
    Picker { panelKey: Panels.picker }
    Launcher { panelKey: Panels.launcher }
    PowerMenu { panelKey: Panels.powerMenu }
    VolumePanel { panelKey: Panels.volume }
    NetworkPanel { panelKey: Panels.network }
    BatteryPanel { panelKey: Panels.battery }
    DateTimePanel { panelKey: Panels.dateTime }
    WeatherPanel { panelKey: Panels.weather }
    MediaPanel { panelKey: Panels.media }
    EmojiPicker { panelKey: Panels.emoji }
    NotifHistoryPanel { panelKey: Panels.notifications }
    SettingsPanel { panelKey: Panels.settings }
    ClipboardPanel { panelKey: Panels.clipboard }
    KeybindsPanel { panelKey: Panels.keybinds }
    FfmpegPanel { panelKey: Panels.ffmpeg }

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
        function micMute(): void { OsdModel.micMute() }
        function brightnessUp(): void { OsdModel.brightnessUp() }
        function brightnessDown(): void { OsdModel.brightnessDown() }
    }
}
