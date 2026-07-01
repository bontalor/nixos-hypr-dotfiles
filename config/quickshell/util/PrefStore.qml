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

    FileView {
        path: Quickshell.statePath("prefs.json")
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
        }
    }
}
