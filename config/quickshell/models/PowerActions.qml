pragma Singleton

import QtQuick
import Quickshell

// Centralized system-action registry for PowerMenu and lockscreen.
// The `notify-send` / `systemctl` / `loginctl` invocations are one-shot
// triggered actions — not polling or subscription state — so they're
// the one place a small Process is the right tool. Quickshell 0.3.0
// ships no `logind` D-Bus service, so for now we keep the established
// `systemctl`/`loginctl` commands, just gathered in one source of truth
// instead of duplicated between PowerMenu.qml and LockSurface.qml.

Singleton {
    property var actions: [
        { name: "Lock",       glyph: "\uf023", command: ["quickshell", "-p", Quickshell.shellDir + "/lockscreen/shell.qml"] },
        { name: "Logout",     glyph: "\uf2f5", command: ["loginctl", "terminate-user", Quickshell.env("USER")] },
        { name: "Suspend",    glyph: "\uf186", command: ["systemctl", "suspend"] },
        { name: "Reboot",     glyph: "\uf2f9", command: ["systemctl", "reboot"] },
        { name: "Power Off",  glyph: "\uf011", command: ["systemctl", "poweroff"] }
    ]
}