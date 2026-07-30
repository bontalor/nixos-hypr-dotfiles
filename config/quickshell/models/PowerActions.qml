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
// The "Lock" command carries a spawn guard:
//   sh -c 'p=…/lock.pid; [ -f $p ] && kill -0 $(cat $p) 2>/dev/null
//          || exec quickshell -p .../lockscreen/shell.qml'
// The lockscreen Quickshell instance writes its own `$PPID` to that
// pid file at startup (see lockscreen/LockContext.qml) and removes it on
// unlock, so repeated `Lock` presses or a stuck Hyprland bind can't pile
// up ext-session-lock-v1 instances. `kill -0` returns 0 only if the pid
// is ours-and-alive; a stale pid file (lockscreen crashed, the PID
// reused by an unrelated process) just means we spawn a fresh instance
// and let ext-session-lock-v1 itself reject any duplicates.

Singleton {
    property var actions: [
        { _lockOnly: true,
          name: "Lock", glyph: "\u{f023}", command: ["sh", "-c",
            "p=\"" + Paths.stateDir + "/lock.pid\"; "
            + "if [ -f \"$p\" ] && kill -0 \"$(cat \"$p\")\" 2>/dev/null; then exit 0; fi; "
            + "exec quickshell -p \"" + Quickshell.shellDir + "/lockscreen/shell.qml\""]
        },
        { name: "Logout",     glyph: "\u{f2f5}", command: ["loginctl", "terminate-user", Quickshell.env("USER")] },
        { name: "Suspend",    glyph: "\u{f186}", command: ["systemctl", "suspend"] },
        { name: "Reboot",     glyph: "\u{f2f9}", command: ["systemctl", "reboot"] },
        { name: "Power Off",  glyph: "\u{f011}", command: ["systemctl", "poweroff"] }
    ]
}