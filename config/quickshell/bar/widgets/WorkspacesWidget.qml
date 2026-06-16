import "../../theme"
import QtQuick
import Quickshell
import Quickshell.Hyprland
Row {
    spacing: 10
    Repeater {
        model: 9
        Item {
            property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
            property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
            width: 30
            height: 30

            Rectangle {
                anchors.fill: parent
                color: isActive || mouseArea.containsMouse ? Qt.alpha(Colors.base08, 0.75) : "transparent"
            }

            Text {
                id: textItem
                anchors.centerIn: parent
                text: index + 1
                font.pixelSize: 16
                font.family: "JetBrainsMono Nerd Font"
                color: Hyprland.toplevels.values.some(t => t.workspace?.id === index + 1) ? Colors.base04 : Colors.foreground
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
