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
            reloadNotifyTimer.restart()
        }
    }

    Timer {
        id: reloadNotifyTimer
        interval: 250
        onTriggered: {
            notifyProc.command = ["notify-send", "Quickshell", "Config reloaded", "-i", "dialog-information"]
            // Kill any in-flight notify-send first: setting `running = true`
            // on an already-running Process is a no-op, so a reload that
            // fires while a prior notify-send is still running would be
            // silently dropped (and `command` set on a running Process
            // has no effect either). Toggling false then true forces a
            // fresh spawn so every reload actually surfaces a toast.
            notifyProc.running = false
            notifyProc.running = true
        }
    }

    Process {
        id: notifyProc
        running: false
    }
}
