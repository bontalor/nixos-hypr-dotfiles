// OSD popup — mirrors the notification popup's shape and drop-shadow
// style, but anchored to the bottom center of the screen. Visible only
// while OsdModel.hideTimer is running (5s after each trigger).
//
// Icon on the left (OsdModel.glyph), a value bar on the right: filled
// portion is Colors.foreground, remainder is Colors.foreground @ 0.25.

import "../theme"
import "."
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.anchors { bottom: true; left: true; right: true }
    WlrLayershell.margins { bottom: 10 }

    color: "transparent"
    implicitHeight: Theme.popupHeight + 10   // bg + bottom shadow
    visible: OsdModel.visible

    Item {
        width: Theme.popupWidth + 10
        height: Theme.popupHeight + 10
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            id: bg
            width: parent.width - 10
            height: parent.height - 10
            color: Qt.alpha(Colors.background, 0.76)

            Item {
                anchors {
                    fill: parent
                    leftMargin: Theme.margin
                    rightMargin: Theme.margin
                    topMargin: Theme.margin
                    bottomMargin: Theme.margin
                }

                Text {
                    id: icon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: OsdModel.glyph
                    color: Colors.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPixelSizeLarge
                }

                Rectangle {
                    id: bar
                    anchors {
                        left: icon.right
                        leftMargin: Theme.margin
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    height: 8
                    color: Qt.alpha(Colors.foreground, 0.25)

                    Rectangle {
                        width: parent.width * OsdModel.value
                        height: parent.height
                        color: Colors.foreground
                    }
                }
            }
        }

        // Drop-shadow pair — identical geometry to NotifPopup.qml.
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
