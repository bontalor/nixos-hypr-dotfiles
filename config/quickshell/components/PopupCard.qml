// Standard popup card: the background Rectangle + DropShadow pair that
// NotifPopup and OsdPopup previously each hand-rolled. Size the card to
// include the shadow extent (Theme.margin right/below, matching the
// popup*WithShadow constants); content children land directly in the
// background Rectangle, so anchors resolve against it.

import "."
import "../theme"
import QtQuick

Item {
    id: root

    default property alias content: bg.data
    property alias background: bg
    // Rectangle border (e.g. the critical-notification outline).
    property alias border: bg.border

    Rectangle {
        id: bg
        width: parent.width - Theme.margin
        height: parent.height - Theme.margin
        color: Qt.alpha(Colors.background, Theme.alphaWindow)
    }

    DropShadow { anchors.fill: parent }
}
