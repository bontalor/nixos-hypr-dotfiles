pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persisted shell preferences — one JSON file in the XDG state dir.
//
// statePath keeps mutable state out of the config tree (which may be a
// read-only home-manager symlink on NixOS, and shouldn't collect git
// noise). FileView + JsonAdapter round-trip the file natively: no
// sh/printf/cat subprocesses, no async read callbacks. blockLoading
// makes prefs available synchronously at startup, so consumers read
// them directly in bindings or Component.onCompleted.
//
// Add a new preference by declaring a property on the adapter and an
// alias here; writes persist automatically via onAdapterUpdated.

Singleton {
    property alias batteryDevice: adapter.batteryDevice
    property alias weatherUnit: adapter.weatherUnit
    property alias weatherCity: adapter.weatherCity
    property alias wallpaper: adapter.wallpaper
    property alias wallpaperDir: adapter.wallpaperDir
    property alias distroIcon: adapter.distroIcon
    property alias barPosition: adapter.barPosition
    property alias timeFormat: adapter.timeFormat
    property alias notifPopups: adapter.notifPopups
    property alias notifExpireSec: adapter.notifExpireSec
    property alias emojiRecents: adapter.emojiRecents
    property alias visualizer: adapter.visualizer
    property alias fingerprintUnlock: adapter.fingerprintUnlock
    property alias terminal: adapter.terminal
    property alias clipboardHistory: adapter.clipboardHistory
    property alias timeSeconds: adapter.timeSeconds
    property alias weekStart: adapter.weekStart
    property alias batteryWarnLevel: adapter.batteryWarnLevel
    property alias allLowercase: adapter.allLowercase

    FileView {
        // Not Quickshell.statePath(): that resolves to a by-shell/<hash>
        // directory unique to each shell instance, and the lockscreen runs
        // as its own instance (-p lockscreen/shell.qml) but must see the
        // same prefs (fingerprintUnlock, timeFormat). One shared file in
        // the parent quickshell state dir works for both.
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/quickshell/prefs.json"
        blockLoading: true
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            property string batteryDevice: ""
            property string weatherUnit: "F"      // "F" | "C"
            property string weatherCity: ""        // "" = auto (IP-based)
            property string wallpaper: ""
            property string wallpaperDir: ""       // "" = Paths default (~/walls)
            property string distroIcon: ""         // "" = auto-detect from /etc/os-release
            property string barPosition: "top"     // "top" | "bottom"
            property string timeFormat: "12h"      // "12h" | "24h"
            property bool notifPopups: true
            property int notifExpireSec: 5         // popup auto-expire (seconds)
            property string emojiRecents: ""       // space-separated MRU list
            property bool visualizer: true
            property bool fingerprintUnlock: true
            property string terminal: ""           // "" = foot; must accept `-e <cmd>`
            property bool clipboardHistory: true   // wl-paste watchers on/off
            property bool timeSeconds: true        // seconds in the bar clock
            property string weekStart: "sunday"    // "sunday" | "monday" (calendar)
            property int batteryWarnLevel: 20      // low-battery warning percent
        property bool allLowercase: false
        }
    }
}
