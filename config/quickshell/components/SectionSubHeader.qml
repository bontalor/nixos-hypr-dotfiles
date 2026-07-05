// Dimmed bold sub-header above a group of rows inside a panel section
// ("My devices", "Wi-Fi", …). Replaces the identical 7-line ThemeText
// block previously duplicated across NetworkPanel's sections. Height is
// Theme.subHeaderHeight — NetworkPanel's scrollToSelection arithmetic
// counts these headers, so keep the two in sync via the constant.
// Caller sets `text` and `visible`.

import "."
import "../theme"
import QtQuick

ThemeText {
    width: parent.width
    height: Theme.subHeaderHeight
    leftPadding: Theme.margin
    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
    font.bold: true
}
