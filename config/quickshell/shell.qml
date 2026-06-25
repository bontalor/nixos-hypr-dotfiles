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

    property var overlayPanels: ({
        "powermenu": powerMenu,
        "picker": picker,
        "launcher": launcher,
        "volume": volumePanel,
        "network": networkPanel,
        "battery": batteryPanel,
        "datetime": dateTimePanel,
        "weather": weatherPanel,
        "media": mediaPanel,
        "emoji": emojiPicker
    })

    function togglePanel(name) {
        var keys = Object.keys(overlayPanels);
        for (var i = 0; i < keys.length; i++) {
            var key = keys[i];
            var p = overlayPanels[key];
            p.visible = (key === name) ? !p.visible : false;
        }
    }

    IpcHandler {
        target: "overlay"
        enabled: true
        function toggle(name: string): void {
            togglePanel(name);
        }
    }
}
