import "../theme"
import "../models"
import "."
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

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
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            source: modelData?.icon ? Quickshell.iconPath(modelData.icon, false) : ""
            width: Theme.iconSize
            height: Theme.iconSize
            visible: source.toString() !== ""
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