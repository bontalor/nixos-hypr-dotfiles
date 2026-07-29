// Centered dim placeholder for empty panel sections ("No devices",
// "No Wi-Fi networks found", …). Replaces the identical 8-line block
// previously duplicated across VolumePanel/NetworkPanel/BatteryPanel/
// NotifHistoryPanel. Caller sets `text` and `visible`.

import "."
import "../theme"
import QtQuick

ThemeText {
    width: parent.width
    height: Theme.searchRowHeight
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
}
