import "../../theme"
import "../../components"
import QtQuick
import Quickshell
import Quickshell.Hyprland

Row {
    id: root
    spacing: Theme.margin

    property var activeToplevelWsIds: {
        var ids = {}
        var toplevels = Hyprland.toplevels.values
        for (var i = 0; i < toplevels.length; i++) {
            var wsId = toplevels[i].workspace?.id
            if (wsId) ids[wsId] = true
        }
        return ids
    }

    // Bind to the actual Hyprland workspace list instead of a hardcoded
    // `model: 9`. Falls back to 9 if the Hyprland service hasn't populated
    // yet, so the bar is usable before the compositor reports workspaces.
    property int wsCount: {
        var ws = Hyprland.workspaces
        var n = ws ? ws.values.length : 0
        return Math.max(9, n)
    }

    Repeater {
        model: root.wsCount
        Item {
            property int wsId: index + 1
            property bool isActive: Hyprland.focusedWorkspace?.id === wsId
            property bool hasToplevels: root.activeToplevelWsIds[wsId] === true
            width: Theme.barHeight
            height: Theme.barHeight

            Rectangle {
                anchors.fill: parent
                color: isActive || mouseArea.containsMouse
                    ? Qt.alpha(Colors.foreground, Theme.alphaHover)
                    : "transparent"
            }

            Rectangle {
                width: 4
                height: 4
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                color: hasToplevels ? Colors.foreground : "transparent"
            }

            ThemeText {
                anchors.centerIn: parent
                text: wsId
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Raw Hyprland dispatch string (the only inline
                    // compositor command in the shell): focuses wsId.
                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + "})")
                }
            }
        }
    }
}
