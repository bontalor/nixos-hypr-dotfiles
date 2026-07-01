pragma Singleton

import QtQuick
import Quickshell

// User-specific filesystem locations, gathered in one place so a future
// home-manager module can template a single file instead of chasing
// hardcoded paths through panels. Everything here is external input to
// the shell — wallpapers, the pywal cache, the emoji data file.

Singleton {
    readonly property string home: Quickshell.env("HOME")

    readonly property string wallpaperDir: home + "/walls"
    readonly property string setwallBin: home + "/.local/bin/setwall"
    readonly property string emojiData: home + "/.local/share/emoji-test.txt"
    readonly property string walColors: home + "/.cache/wal/colors.json"
    readonly property string walWallpaper: home + "/.cache/wal/wal"
}
