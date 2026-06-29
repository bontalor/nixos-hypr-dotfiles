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
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData?.glyph ?? ""
            color: Colors.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData?.name ?? ""
            color: Colors.foreground
            font.pixelSize: Theme.fontPixelSize
            font.family: Theme.fontFamily
        }
    }
}