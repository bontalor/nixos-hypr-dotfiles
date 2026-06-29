import "../../theme"
import "../../notifications"
import QtQuick

Item {
    id: root
    width: notifText.width + 20
    height: 30

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
    }

    Text {
        id: notifText
        anchors.centerIn: parent
        text: "(" + NotifDaemon.history.count + ")"
        font.pixelSize: Theme.fontPixelSize
        font.family: Theme.fontFamily
        color: Colors.foreground
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("notifications")
    }
}