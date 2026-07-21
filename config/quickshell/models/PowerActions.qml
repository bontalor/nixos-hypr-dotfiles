pragma Singleton

import QtQuick
import Quickshell
import "../util"

// Centralized system-action registry for PowerMenu and lockscreen.
// The `notify-send` / `systemctl` / `loginctl` invocations are one-shot
// triggered actions — not polling or subscription state — so they're
// the one place a small Process is the right tool. Quickshell 0.3.0
// ships no `logind` D-Bus service, so for now we keep the established
// `systemctl`/`loginctl` commands, just gathered in one source of truth.
//
// The lockscreen reaches this singleton via a `lockscreen/models`
// symlink (config-root isolation would otherwise hide it). LockSurface
// filters out entries with `_lockOnly: true` so the lockscreen surface
// doesn't offer a redundant "Lock" action (it's already locked).
// Identified by `_lockOnly` rather than display name so renaming
// "Lock" doesn't break the filter.
//
// The Lock action is spawn-guarded: lockscreen/LockContext.qml writes
// its PID to Paths.lockMarker on startup and clears it on unlock, so a
// repeated Lock bind (or button mash) can't pile up lockscreen
// instances. The shell script reads the marker, verifies the PID is
// alive with `kill -0`, and only spawns when nothing is running.
// Uses array-argv (positional substitution via `sh -c "…$1…$2…" sh
// /tmp/lock.pid /path/to/lockshell`) so Spaces/quotes in the shellDir
// can't break the spawn.

Singleton {
    property var actions: [
        { _lockOnly: true,
          name: "Lock", glyph: "\uf023", command: ["sh", "-c",
            'm="$1"; if [ -f "$m" ]; then pid=$(cat "$m"); ' +
            'if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then exit 0; fi; fi; ' +
            'quickshell -p "$2" &',
            "sh", Paths.lockMarker, Quickshell.shellDir + "/lockscreen/shell.qml"
        ] },
        { name: "Logout",     glyph: "\uf2f5", command: ["loginctl", "terminate-user", Quickshell.env("USER")] },
        { name: "Suspend",    glyph: "\uf186", command: ["systemctl", "suspend"] },
        { name: "Reboot",     glyph: "\uf2f9", command: ["systemctl", "reboot"] },
        { name: "Power Off",  glyph: "\uf011", command: ["systemctl", "poweroff"] }
    ]
}