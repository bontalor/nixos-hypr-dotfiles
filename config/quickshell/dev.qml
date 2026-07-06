// Single-panel dev harness — iterate on one panel without running the
// whole shell (bar, popups, daemons):
//
//   LOR_PANEL=weather qs -p dev.qml
//
// LOR_PANEL is a Panels registry key (components/Panels.qml); defaults to
// the launcher. Only the requested panel is instantiated (so e.g. the
// notifications panel's NotificationServer only spins up when actually
// under test), forced visible, and the process exits when its window
// closes (Escape). panelKey stays unset — nothing registers.
//
// Loading panels by file path instead would be map-free, but dynamic
// qs:-scheme URLs break the panels' relative directory imports
// ("Panel is not a type"), so an explicit component map it is.

import "./wallpaper"
import "./launcher"
import "./power"
import "./network"
import "./volume"
import "./time"
import "./weather"
import "./media"
import "./emoji"
import "./notifications"
import "./settings"
import "./clipboard"
import "./keybinds"
import "./ffmpeg"
import QtQuick
import Quickshell

ShellRoot {
    id: root

    property string which: (Quickshell.env("LOR_PANEL") || "launcher").toLowerCase()

    readonly property var panelComponents: ({
        "picker": cPicker,
        "launcher": cLauncher,
        "powermenu": cPowerMenu,
        "volume": cVolume,
        "network": cNetwork,
        "battery": cBattery,
        "datetime": cDateTime,
        "weather": cWeather,
        "media": cMedia,
        "emoji": cEmoji,
        "notifications": cNotifications,
        "settings": cSettings,
        "clipboard": cClipboard,
        "keybinds": cKeybinds,
        "ffmpeg": cFfmpeg
    })

    LazyLoader {
        active: true
        component: root.panelComponents[root.which] ?? cLauncher
        onItemChanged: if (item) item.visible = true
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

    Connections {
        target: Quickshell
        function onLastWindowClosed() { Qt.quit() }
    }
}
