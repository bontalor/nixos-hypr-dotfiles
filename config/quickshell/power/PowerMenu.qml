// Subprocess dependencies: systemctl (suspend/reboot/poweroff),
// loginctl (terminate-user logout), quickshell -p lockscreen/shell.qml
// (lock).

pragma ComponentBehavior: Bound

import "../theme"
import "../components"
import "../models"
import "../util"
import "."
import QtQuick

SearchPanel {
    id: root
    title: "Power Menu"

    items: PowerActions.actions

    // Queue + drain pattern (see EmojiPicker for the rationale):
    // `Process.running = true` on an already-running Process is a
    // no-op, so rapid Enter presses used to silently drop later power
    // actions. The queue is drained on `onQueueFinished` (fired by
    // CheckedProcess on both success and failure). For Suspend/Reboot
    // the panel is hidden after the first action, but cancelling-and-
    // retrying a delayed logout no longer drops the subsequent call.
    property var cmdQueue: []

    function drainCmdQueue() {
        if (runner.running || root.cmdQueue.length === 0) return
        runner.command = root.cmdQueue.shift()
        runner.running = true
    }

    onLaunched: function(idx) {
        var action = root.filtered[idx]
        if (!action) return
        root.cmdQueue.push(action.command)
        root.drainCmdQueue()
        root.visible = false
    }

    CheckedProcess {
        id: runner
        running: false
        onQueueFinished: root.drainCmdQueue()
    }

    rowDelegate: SearchRow {
        id: powerRow
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: powerRow.modelData?.glyph ?? ""
            font.pixelSize: Theme.iconSize
        }
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: powerRow.modelData?.name ?? ""
        }
    }
}