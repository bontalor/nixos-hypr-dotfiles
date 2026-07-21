// Subprocess dependencies: systemctl (suspend/reboot/poweroff),
// loginctl (terminate-user logout), quickshell -p lockscreen/shell.qml
// (lock).

import "../theme"
import "../components"
import "../models"
import "../util"
import "."
import QtQuick

pragma ComponentBehavior: Bound

SearchPanel {
    id: root
    title: "Power Menu"

    items: PowerActions.actions

    onLaunched: function(idx) {
        var action = root.filtered[idx]
        if (!action) return
        runner.command = action.command
        runner.running = true
        root.visible = false
    }

    CheckedProcess {
        id: runner
        running: false
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