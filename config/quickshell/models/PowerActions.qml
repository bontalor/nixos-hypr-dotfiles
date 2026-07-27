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

Singleton {
    property var actions: [
        { _lockOnly: true,
          name: "Lock", glyph: "\uf023", command: ["quickshell", "-p",
            Quickshell.shellDir + "/lockscreen/shell.qml"]
        },
        { name: "Logout",     glyph: "\uf2f5", command: ["loginctl", "terminate-user", Quickshell.env("USER")] },
        { name: "Suspend",    glyph: "\uf186", command: ["systemctl", "suspend"] },
        { name: "Reboot",     glyph: "\uf2f9", command: ["systemctl", "reboot"] },
        { name: "Power Off",  glyph: "\uf011", command: ["systemctl", "poweroff"] }
    ]
}