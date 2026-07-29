pragma Singleton

import QtQuick
import Quickshell

// User-specific filesystem locations, gathered in one place instead of
// chasing hardcoded paths through panels. Everything here is external
// input to the shell — wallpapers, the pywal cache, the emoji data file.

Singleton {
    readonly property string home: Quickshell.env("HOME")

    // Strip the `file://` prefix from a QUrl-as-string and decode its
    // escapes. Platform FileDialog returns a QUrl; callers without this
    // helper used to inline the (URL-encoded) string into argv. Reused
    // by every file-picker surface (FfmpegPanel, wallpaper Picker).
    function urlToLocalFile(url) {
        var s = url ? url.toString() : ""
        if (s.startsWith("file://")) return decodeURIComponent(s.slice(7))
        return s
    }

    // Expand a leading "~/" — Settings path prefs are typed by hand.
    function expandHome(p) { return p && p.startsWith("~/") ? home + p.slice(1) : p }

    // Shared shell state dir (see PrefStore for why not statePath()).
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state")
                                       + "/quickshell"

    // Overridable via Settings (PrefStore.wallpaperDir); "" = default.
    readonly property string wallpaperDir: expandHome(PrefStore.wallpaperDir) || home + "/walls"
    readonly property string setwallBin: home + "/.local/bin/setwall"
    readonly property string emojiData: home + "/.local/share/emoji-test.txt"
    readonly property string walColors: home + "/.cache/wal/colors.json"
    readonly property string walWallpaper: home + "/.cache/wal/wal"

    // Lock spawn-guard marker — the lockscreen instance writes its PID
    // here on startup and deletes it on unlock (see lockscreen/LockContext).
    // The PowerMenu's Lock action reads it back to skip a redundant
    // spawn when a lockscreen is already running (e.g. user mashed the
    // Lock button or stuffed the bind).
    readonly property string lockMarker: stateDir + "/lock.pid"
}
