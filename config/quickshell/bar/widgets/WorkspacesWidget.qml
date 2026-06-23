import "../../theme"
import QtQuick
import Quickshell
import Quickshell.Hyprland
Row {
    spacing: 10

    property var workspaceIds: (function() {
        var ids = {}
        var vals = Hyprland.workspaces.values
        for (var i = 0; i < vals.length; i++) ids[vals[i].id] = true
        return ids
    })()
    property var occupiedWorkspaces: (function() {
        var ids = {}
        var vals = Hyprland.toplevels.values
        for (var i = 0; i < vals.length; i++) {
            var wid = vals[i].workspace?.id
            if (wid) ids[wid] = true
        }
        return ids
    })()
    property int focusedWorkspaceId: Hyprland.focusedWorkspace?.id ?? -1

    Repeater {
        model: 9
        Item {
            readonly property bool wsExists: root.workspaceIds[index + 1] === true
            readonly property bool isActive: root.focusedWorkspaceId === (index + 1)
            readonly property bool isOccupied: root.occupiedWorkspaces[index + 1] === true
            width: 30
            height: 30

            Rectangle {
                anchors.fill: parent
                color: isActive || mouseArea.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
            }

            Rectangle {
                width: 5
                height: 5
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 0
                color: isOccupied ? Colors.foreground : "transparent"
            }

            Text {
                id: textItem
                anchors.centerIn: parent
                text: index + 1
                font.pixelSize: 16
                font.family: "JetBrainsMono Nerd Font"
                color: Colors.foreground
            }
            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + (index + 1) + "})")
                }
            }
        }
    }
}
