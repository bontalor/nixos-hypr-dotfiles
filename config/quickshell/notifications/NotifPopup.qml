import "../theme"
import "."
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Widgets

PanelWindow {
    id: root
    WlrLayershell.namespace: "quickshell:notification"
    WlrLayershell.anchors { top: true; right: true }
    WlrLayershell.margins { top: 20; right: Theme.margin + 20 }

    color: "transparent"
    implicitWidth: Theme.popupWidth + 10    // bg + right shadow
    implicitHeight: root.totalHeight
    visible: NotifDaemon.activePopups.count > 0

    // Each popup is fixed-size (Theme.popupWidth x popupHeight) + the
    // 10px drop-shadow pair, so the window height is a simple sum.
    property int totalHeight: {
        var n = NotifDaemon.activePopups.count
        return n * (Theme.popupHeight + 10) + Math.max(0, n - 1) * 10
    }

    Column {
        width: parent.width
        spacing: 10

        Repeater {
            model: NotifDaemon.activePopups

            delegate: Item {
                required property string summary
                required property string body
                required property string appName
                required property int notifId
                required property int urgency

                width: parent.width
                height: Theme.popupHeight + 10

                Rectangle {
                    id: bg
                    width: parent.width - 10
                    height: parent.height - 10
                    color: Qt.alpha(Colors.background, 0.76)
                    border.width: urgency === NotificationUrgency.Critical ? 2 : 0
                    border.color: Colors.base08

                    Column {
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Theme.margin; rightMargin: Theme.margin; topMargin: Theme.margin }
                        spacing: 6

                    Text {
                        width: parent.width
                        text: summary || ""
                        color: Colors.foreground
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: body || ""
                        color: Colors.foreground
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                    }

                    MouseArea {
                        anchors.fill: parent
                        propagateComposedEvents: true
                        onClicked: NotifDaemon.dismissPopup(notifId)
                    }
                }

                Rectangle {
                    x: 10
                    y: parent.height - 10
                    width: parent.width - 10
                    height: 10
                    color: Qt.alpha("#000000", Theme.alphaBackground)
                }
                Rectangle {
                    x: parent.width - 10
                    y: 10
                    width: 10
                    height: parent.height - 20
                    color: Qt.alpha("#000000", Theme.alphaBackground)
                }
            }
        }
    }
}
