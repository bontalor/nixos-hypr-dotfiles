import "../../theme"
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.DBusMenu
import Quickshell.Widgets

Item {
    id: root
    width: trayRow.width
    height: 30

    property var parentWindow

    Row {
        id: trayRow
        spacing: 10

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayDelegate
                required property var modelData
                width: 30
                height: 30

                Rectangle {
                    anchors.fill: parent
                    color: delegateMouse.containsMouse ? Colors.background : "transparent"
                }

                QsMenuAnchor {
                    id: menuAnchor
                    menu: trayDelegate.modelData.menu
                    anchor.window: parentWindow
                    anchor.item: trayDelegate
                    anchor.edges: Edges.Bottom | Edges.Left
                }

                IconImage {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: trayDelegate.modelData.icon
                    mipmap: true
                    backer.sourceSize.width: 22 * Screen.devicePixelRatio
                    backer.sourceSize.height: 22 * Screen.devicePixelRatio
                }

                MouseArea {
                    id: delegateMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            if (trayDelegate.modelData.hasMenu) {
                                menuAnchor.open()
                            }
                        } else if (mouse.button === Qt.LeftButton) {
                            trayDelegate.modelData.activate()
                        }
                    }
                }
            }
        }
    }
}
