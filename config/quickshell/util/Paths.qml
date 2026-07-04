pragma Singleton

import QtQuick
import Quickshell

// User-specific filesystem locations, gathered in one place instead of
// chasing hardcoded paths through panels. Everything here is external
// input to the shell — wallpapers, the pywal cache, the emoji data file.

Singleton {
    readonly property string home: Quickshell.env("HOME")

    // Expand a leading "~/" — Settings path prefs are typed by hand.
    function expandHome(p) { return p && p.startsWith("~/") ? home + p.slice(1) : p }

    // Overridable via Settings (PrefStore.wallpaperDir); "" = default.
    readonly property string wallpaperDir: expandHome(PrefStore.wallpaperDir) || home + "/walls"
    readonly property string setwallBin: home + "/.local/bin/setwall"
    readonly property string emojiData: home + "/.local/share/emoji-test.txt"
    readonly property string walColors: home + "/.cache/wal/colors.json"
    readonly property string walWallpaper: home + "/.cache/wal/wal"
}
