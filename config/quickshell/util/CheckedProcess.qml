// Fire-and-forget Process that surfaces failures as a shell
// notification instead of dying silently. Drop-in for the usual
//   proc.command = [...]; proc.running = true
// pattern; on a non-zero exit it raises NotifDaemon.notify with the
// collected stderr.
//
// Do NOT use from the lockscreen instance: referencing NotifDaemon
// there would spin up a second NotificationServer that fights the main
// shell over the D-Bus name.

import QtQuick
import Quickshell.Io
import Quickshell.Services.Notifications
import "../notifications"

Process {
    id: root

    // Notification summary prefix; defaults to the executable name.
    property string label: ""
    // When true, a non-zero exit is silently dropped (no notification).
    // Used by the OsdModel brightness "silent prime" so a system without
    // a backlight (a desktop, or a machine with no backlight module
    // loaded) doesn't pop a "brightnessctl info failed" toast on every
    // shell startup. The notification is left on by default for one-off
    // user-driven commands where silent failure would be confusing.
    property bool silent: false
    signal queueFinished()

    stderr: StdioCollector { id: errCollector }

    onExited: (exitCode, exitStatus) => {
        if (exitCode === 0) { root.queueFinished(); return }
        if (!root.silent) {
            var what = root.label
                || (root.command && root.command.length > 0 ? root.command[0] : "command")
            var detail = (errCollector.text || "").trim()
            // Distinguish a crash (SIGSEGV, etc.) from a normal non-zero
            // exit — `exitStatus` is `Process.CrashExit` when the
            // process was killed by a signal. Previously a crash and a
            // clean failure surfaced as the same "exit <code>" toast.
            var suffix = exitStatus === Process.CrashExit ? " (crashed)" : ""
            NotifDaemon.notify(what + " failed (exit " + exitCode + ")" + suffix,
                detail.slice(0, 300), NotificationUrgency.Normal)
        }
        root.queueFinished()
    }
}
