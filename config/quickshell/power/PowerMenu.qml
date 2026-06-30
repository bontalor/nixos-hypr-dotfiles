import "../theme"
import "../models"
import "."
import QtQuick
import Quickshell.Io

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

    Process {
        id: runner
        running: false
    }

    rowDelegate: SearchRow {
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData?.glyph ?? ""
            font.pixelSize: Theme.iconSize
        }
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData?.name ?? ""
        }
    }
}