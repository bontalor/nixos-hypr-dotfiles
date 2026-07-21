import "../notifications"
import "../clipboard"
import "../emoji"
import "../ffmpeg"
import "../keybinds"
import "../launcher"
import "../media"
import "../network"
import "../power"
import "../settings"
import "../time"
import "../volume"
import "../wallpaper"
import "../weather"
import QtQuick

Item {
    // Per-key access for the dev harness (dev.qml):
    //     PanelComponents { id: shared }
    //     Loader { sourceComponent: shared.get("weather") ?? shared.get("launcher") }
    //
    // Production wiring lives in shell.qml, which instantiates each
    // panel directly (`NetworkPanel { panelKey: Panels.network }`),
    // so this map exists only to locate a Component by key.

    function get(key) {
        switch (key) {
        case "picker": return cPicker
        case "launcher": return cLauncher
        case "powermenu": return cPowerMenu
        case "volume": return cVolume
        case "network": return cNetwork
        case "battery": return cBattery
        case "datetime": return cDateTime
        case "weather": return cWeather
        case "media": return cMedia
        case "emoji": return cEmoji
        case "notifications": return cNotifications
        case "settings": return cSettings
        case "clipboard": return cClipboard
        case "keybinds": return cKeybinds
        case "ffmpeg": return cFfmpeg
        default: return null
        }
    }

    Component { id: cPicker; Picker {} }
    Component { id: cLauncher; Launcher {} }
    Component { id: cPowerMenu; PowerMenu {} }
    Component { id: cVolume; VolumePanel {} }
    Component { id: cNetwork; NetworkPanel {} }
    Component { id: cBattery; BatteryPanel {} }
    Component { id: cDateTime; DateTimePanel {} }
    Component { id: cWeather; WeatherPanel {} }
    Component { id: cMedia; MediaPanel {} }
    Component { id: cEmoji; EmojiPicker {} }
    Component { id: cNotifications; NotifHistoryPanel {} }
    Component { id: cSettings; SettingsPanel {} }
    Component { id: cClipboard; ClipboardPanel {} }
    Component { id: cKeybinds; KeybindsPanel {} }
    Component { id: cFfmpeg; FfmpegPanel {} }
}