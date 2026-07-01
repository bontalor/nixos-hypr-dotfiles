// Reload notifier — fires a desktop notification on each Quickshell
// config reload. The notify-send call routes through the D-Bus
// NotificationServer that NotifDaemon owns, so it surfaces as a popup
// via the normal daemon path (snapshot → expire → history) rather than
// calling NotifDaemon directly. This is intentional — don't "fix" it
// by calling NotifDaemon.handleNotification(), which would bypass the
// daemon's snapshot/expire logic.

import QtQuick
import Quickshell
import Quickshell.Io

Scope {

    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
            notifyProc.command = ["notify-send", "Quickshell", "Config reloaded", "-i", "dialog-information"]
            notifyProc.running = true
        }
    }

    Process {
        id: notifyProc
        running: false
    }
}
