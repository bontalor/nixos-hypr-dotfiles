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
    implicitHeight: Theme.popupHeight
    visible: NotifDaemon.activePopups.count > 0

    property int totalHeight: {
        var h = 0
        var m = NotifDaemon.activePopups
        for (var i = 0; i < m.count; i++) {
            var e = m.get(i)
            h += Math.min(140, 60 + Math.ceil((e.body || "").length / 40) * 20) + 10
        }
        return h + Math.max(0, m.count - 1) * 10
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
                height: Theme.popupHeight

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
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: parent.width
                        text: body || ""
                        color: Colors.foreground
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                        wrapMode: Text.WordWrap
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
