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
    property alias barPosition: adapter.barPosition
    property alias timeFormat: adapter.timeFormat
    property alias notifPopups: adapter.notifPopups
    property alias visualizer: adapter.visualizer
    property alias fingerprintUnlock: adapter.fingerprintUnlock

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
            property string weatherUnit: ""
            property string weatherCity: ""
            property string wallpaper: ""
            property string barPosition: "top"     // "top" | "bottom"
            property string timeFormat: "12h"      // "12h" | "24h"
            property bool notifPopups: true
            property bool visualizer: true
            property bool fingerprintUnlock: true
        }
    }
}
