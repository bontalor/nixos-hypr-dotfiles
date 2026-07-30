pragma ComponentBehavior: Bound

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

    // Fixed 1..9 slots, always visible. Clicking slot i dispatches
    // `focus workspace i` (Hyprland creates it on demand if absent),
    // so the bar is usable before the compositor reports workspaces
    // and stays stable across workspace create/delete. Workspaces
    // outside 1..9 simply don't get a slot — by design.
    readonly property int wsCount: Theme.workspacesMin

    Repeater {
        model: root.wsCount
        Item {
            id: ws
            required property int index
            property int wsId: index + 1
            property bool isActive: Hyprland.focusedWorkspace?.id === wsId
            property bool hasToplevels: root.activeToplevelWsIds[wsId] === true
            width: Theme.barHeight
            height: Theme.barHeight

            Rectangle {
                anchors.fill: parent
                color: ws.isActive || mouseArea.containsMouse
                    ? Qt.alpha(Colors.foreground, Theme.alphaHover)
                    : "transparent"
            }

            Rectangle {
                width: 4
                height: 4
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                color: ws.hasToplevels ? Colors.foreground : "transparent"
            }

            ThemeText {
                anchors.centerIn: parent
                text: ws.wsId
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Raw Hyprland dispatch string (the only inline
                    // compositor command in the shell): focuses wsId.
                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + ws.wsId + "})")
                }
            }
        }
    }
}
