// OSD popup — mirrors the notification popup's shape and drop-shadow
// style, but anchored to the bottom center of the screen. Visible only
// while OsdModel.hideTimer is running (Theme.osdHideInterval after each
// trigger).
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
    WlrLayershell.margins { bottom: Theme.margin }

    color: "transparent"
    implicitHeight: Theme.popupHeightWithShadow
    visible: OsdModel.visible

    Item {
        width: Theme.popupWidthWithShadow
        height: Theme.popupHeight
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            id: bg
            width: parent.width - Theme.margin
            height: parent.height - Theme.margin
            color: Qt.alpha(Colors.background, Theme.alphaWindow)

            Item {
                anchors {
                    fill: parent
                    margins: Theme.margin
                }

                Item {
                    id: iconSlot
                    width: Theme.fontPixelSizeLarge + Theme.margin
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: Theme.fontPixelSizeLarge

                    ThemeText {
                        anchors.centerIn: parent
                        text: OsdModel.glyph
                        size: "large"
                    }
                }

                Rectangle {
                    id: bar
                    anchors {
                        left: iconSlot.right
                        leftMargin: Theme.margin
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    height: Theme.osdBarHeight
                    color: Qt.alpha(Colors.foreground, Theme.alphaInactive)

                    Rectangle {
                        width: parent.width * OsdModel.value
                        height: parent.height
                        color: Colors.foreground
                    }
                }
            }
        }

        // Shared drop-shadow component (replaces the hand-rolled
        // two-Rectangle block duplicated with NotifPopup/Bar/LockSurface).
        DropShadow {
            anchors.fill: parent
        }
    }
}
