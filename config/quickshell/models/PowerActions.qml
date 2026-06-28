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
        { name: "Lock",       icon: "system-lock-screen", command: ["quickshell", "-p", Quickshell.shellDir + "/lockscreen/shell.qml"] },
        { name: "Logout",     icon: "system-log-out",     command: ["loginctl", "terminate-user", Quickshell.env("USER")] },
        { name: "Suspend",    icon: "system-suspend",     command: ["systemctl", "suspend"] },
        { name: "Reboot",     icon: "system-reboot",      command: ["systemctl", "reboot"] },
        { name: "Power Off",  icon: "system-shutdown",    command: ["systemctl", "poweroff"] }
    ]
}