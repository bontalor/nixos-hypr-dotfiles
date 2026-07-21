// OSD popup — mirrors the notification popup's shape and drop-shadow
// style, but anchored to the bottom center of the screen. Visible only
// while OsdModel.hideTimer is running (OsdModel.hideInterval after each
// trigger).
//
// Icon on the left (OsdModel.glyph), a value bar on the right: filled
// portion is Colors.foreground, remainder is Colors.foreground @ 0.25.

import "../theme"
import "../components"
import "../util"
import "."
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:osd"
    // Bottom-anchored only — the unanchored horizontal axis centers the
    // surface, and sizing the window to the popup keeps it from spanning
    // (and swallowing clicks along) the entire bottom edge while shown.
    WlrLayershell.anchors { bottom: true }
    // ExclusionMode.Ignore skips the bar's reserved zone, so when the
    // bar sits at the bottom the OSD must clear it explicitly.
    WlrLayershell.margins {
        bottom: Theme.margin + (PrefStore.barPosition === "bottom"
                                ? Theme.barHeight + 2 * Theme.barMargin : 0)
    }

    color: "transparent"
    implicitWidth: Theme.popupWidthWithShadow
    implicitHeight: Theme.popupHeightWithShadow
    visible: OsdModel.visible

    PopupCard {
        width: Theme.popupWidthWithShadow
        height: Theme.popupHeight
        anchors.horizontalCenter: parent.horizontalCenter

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
                height: Theme.meterHeight
                color: Qt.alpha(Colors.foreground, Theme.alphaInactive)

                Rectangle {
                    width: parent.width * OsdModel.value
                    height: parent.height
                    color: Colors.foreground
                }
            }
        }
    }
}
