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
    implicitHeight: popupColumn.implicitHeight
    visible: NotifDaemon.activePopups.count > 0 && !fullscreenActive

    property bool fullscreenActive: ToplevelManager.activeToplevel
        ? ToplevelManager.activeToplevel.fullscreen : false

    Column {
        id: popupColumn
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
                // bg height + drop-shadow extent below it.
                height: bg.height + Theme.margin

                Rectangle {
                    id: bg
                    width: parent.width - Theme.margin
                    // Grows with the (line-capped) text; never smaller
                    // than the standard popup so short notifications
                    // keep the usual shape.
                    height: Math.max(Theme.popupHeight - Theme.margin,
                                     contentRow.implicitHeight + 2 * Theme.margin)
                    color: Qt.alpha(Colors.background, Theme.alphaWindow)
                    border.width: urgency === NotificationUrgency.Critical ? 2 : 0
                    border.color: Colors.critical

                    Row {
                        id: contentRow
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
                        }

                        Column {
                            width: parent.width - (appIcon ? 22 : 0)
                            spacing: 4

                            ThemeText {
                                width: parent.width
                                text: summary || ""
                                font.bold: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: Theme.notifSummaryMaxLines
                                elide: Text.ElideRight
                            }

                            ThemeText {
                                width: parent.width
                                text: body || ""
                                wrapMode: Text.WordWrap
                                maximumLineCount: Theme.notifBodyMaxLines
                                elide: Text.ElideRight
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
