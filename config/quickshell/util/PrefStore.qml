pragma Singleton

import "."
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
    // Guard against the write → watch → reload → write echo. The
    // previous design armed a 100 ms `_writing` boolean and skipped any
    // onFileChanged inside that window — but a *real* external write
    // landing in the window (e.g. another shell instance editing prefs)
    // would also be skipped, silently dropping the user's change.
    //
    // A fingerprint instead compares the adapter's current state against
    // the state we last wrote to disk. The echo is now broken at the
    // `onAdapterUpdated` step: when our own write's file-change event
    // reloads the file back into the adapter, the adapter's just-reloaded
    // fingerprint still matches what we last wrote, so `onAdapterUpdated`
    // fires but `_write()` is suppressed and the loop dies. A genuine
    // external edit reloads *different* adapter values → fingerprint
    // differs → `_write()` runs and persists the diff.
    property string _writtenFingerprint: ""

    function _adapterFingerprint() {
        return JSON.stringify([
            adapter.batteryDevice, adapter.weatherUnit, adapter.weatherCity,
            adapter.wallpaper, adapter.wallpaperDir, adapter.distroIcon,
            adapter.barPosition, adapter.timeFormat, adapter.notifPopups,
            adapter.notifExpireSec, adapter.emojiRecents, adapter.visualizer,
            adapter.fingerprintUnlock, adapter.terminal, adapter.clipboardHistory,
            adapter.timeSeconds, adapter.weekStart, adapter.batteryWarnLevel,
            adapter.allLowercase, adapter.fontFamily
        ])
    }

    function _write() {
        root._writtenFingerprint = root._adapterFingerprint()
        writeAdapter()
    }
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
    property alias batteryDevice: adapter.batteryDevice
    property alias allLowercase: adapter.allLowercase
    // Main UI face. "" = Theme.defaultFontFamily (JetBrainsMono Nerd
    // Font). Icon glyphs never use this — ThemeText routes Icon.* text
    // through Theme.iconFamily, so this can be any non-nerd font you
    // have installed (Inter, Cantarell, Noto Sans, …) without breaking
    // glyph icons. Set via Settings → Appearance → Text font.
    property alias fontFamily: adapter.fontFamily

    FileView {
        // Not Quickshell.statePath(): that resolves to a by-shell/<hash>
        // directory unique to each shell instance, and the lockscreen runs
        // as its own instance (-p lockscreen/shell.qml) but must see the
        // same prefs (fingerprintUnlock, timeFormat). One shared file in
        // the parent quickshell state dir works for both — reuse Paths.stateDir
        // so the XDG_STATE_HOME resolution lives in one place.
        path: Paths.stateDir + "/prefs.json"
        blockLoading: true
        atomicWrites: true
        watchChanges: true
        // Unconditional reload: the echo now dies at `onAdapterUpdated`,
        // not here — otherwise an external write landing ~100 ms after
        // our own would be silently dropped (the previous boolean-guard
        // race that this fingerprint approach eliminates).
        onFileChanged: reload()
        onAdapterUpdated: if (root._adapterFingerprint() !== root._writtenFingerprint) root._write()

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
            property string fontFamily: ""           // "" = Theme.defaultFontFamily; see PrefStore.fontFamily alias
        }
    }
}
