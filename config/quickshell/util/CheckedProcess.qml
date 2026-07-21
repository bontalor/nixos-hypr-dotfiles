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
    signal queueFinished()

    stderr: StdioCollector { id: errCollector }

    onExited: (exitCode, exitStatus) => {
        if (exitCode === 0) { root.queueFinished(); return }
        var what = root.label
            || (root.command && root.command.length > 0 ? root.command[0] : "command")
        var detail = (errCollector.text || "").trim()
        NotifDaemon.notify(what + " failed (exit " + exitCode + ")",
            detail.slice(0, 300), NotificationUrgency.Normal)
        root.queueFinished()
    }
}
