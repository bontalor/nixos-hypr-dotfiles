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
// filters out the "Lock" action since it's already on the lockscreen.
//
// The Lock action is spawn-guarded: lockscreen/LockContext.qml writes
// its PID to Paths.lockMarker on startup and clears it on unlock, so a
// repeated Lock bind (or button mash) can't pile up lockscreen
// instances. The shell script reads the marker, verifies the PID is
// alive with `kill -0`, and only spawns when nothing is running.

Singleton {
    property var actions: [
        { name: "Lock", glyph: "\uf023", command: ["sh", "-c",
            "m=\"" + Paths.lockMarker + "\"; "
            + "if [ -f \"$m\" ]; then pid=$(cat \"$m\"); "
            + "if [ -n \"$pid\" ] && kill -0 \"$pid\" 2>/dev/null; then exit 0; fi; fi; "
            + "quickshell -p \"" + Quickshell.shellDir + "/lockscreen/shell.qml\" &"
        ] },
        { name: "Logout",     glyph: "\uf2f5", command: ["loginctl", "terminate-user", Quickshell.env("USER")] },
        { name: "Suspend",    glyph: "\uf186", command: ["systemctl", "suspend"] },
        { name: "Reboot",     glyph: "\uf2f9", command: ["systemctl", "reboot"] },
        { name: "Power Off",  glyph: "\uf011", command: ["systemctl", "poweroff"] }
    ]
}