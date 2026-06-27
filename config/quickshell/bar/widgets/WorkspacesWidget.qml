import "../../theme"
import QtQuick
import Quickshell
import Quickshell.Hyprland
Row {
    spacing: 10

    property var activeToplevelWsIds: {
        var ids = {}
        var toplevels = Hyprland.toplevels.values
        for (var i = 0; i < toplevels.length; i++) {
            var wsId = toplevels[i].workspace?.id
            if (wsId) ids[wsId] = true
        }
        return ids
    }

    Repeater {
        model: 9
        Item {
            property int wsId: index + 1
            property bool isActive: Hyprland.focusedWorkspace?.id === wsId
            property bool hasToplevels: activeToplevelWsIds[wsId] === true
            width: 30
            height: 30

            Rectangle {
                anchors.fill: parent
                color: isActive || mouseArea.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
            }

            Rectangle {
                width: 4
                height: 4
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 0
                color: hasToplevels ? Colors.foreground : "transparent"
            }

            Text {
                id: textItem
                anchors.centerIn: parent
                text: wsId
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
                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + "})")
                }
            }
        }
    }
}
