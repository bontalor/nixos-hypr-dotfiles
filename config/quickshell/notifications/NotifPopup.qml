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
    implicitWidth: Theme.popupWidthWithShadow
    implicitHeight: totalHeight
    visible: NotifDaemon.activePopups.count > 0 && !fullscreenActive

    property bool fullscreenActive: ToplevelManager.activeToplevel
        ? ToplevelManager.activeToplevel.fullscreen : false

    property int totalHeight: {
        var count = NotifDaemon.activePopups.count
        return count * Theme.popupHeight + Math.max(0, count - 1) * Theme.margin
    }

    Column {
        width: parent.width
        spacing: Theme.margin

        Repeater {
            model: NotifDaemon.activePopups

            delegate: Item {
                required property string summary
                required property string body
                required property string appName
                required property string appIcon
                required property string image
                required property int notifId
                required property int urgency

                width: parent.width
                height: Theme.popupHeight

                Rectangle {
                    id: bg
                    width: parent.width - Theme.margin
                    height: parent.height - Theme.margin
                    color: Qt.alpha(Colors.background, 0.76)
                    border.width: urgency === NotificationUrgency.Critical ? 2 : 0
                    border.color: Colors.critical

                    Row {
                        anchors {
                            left: parent.left; right: parent.right; top: parent.top
                            leftMargin: Theme.margin; rightMargin: Theme.margin; topMargin: Theme.margin
                        }
                        spacing: 6

                        // App icon (rendered from the model data the
                        // daemon already collected — previously fetched
                        // and transported but never displayed).
                        IconImage {
                            source: appIcon
                            visible: status === Image.Ready
                            width: 16; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - (appIcon ? 22 : 0)
                            spacing: 4

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
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: NotifDaemon.dismissPopup(notifId)
                    }
                }

                DropShadow {
                    anchors.fill: parent
                }
            }
        }
    }
}
