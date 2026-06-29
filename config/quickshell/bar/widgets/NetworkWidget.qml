import "../../theme"
import "../../models"
import QtQuick

Item {
    id: root
    width: contentRow.width + 20
    height: 30

    // Direct bindings to the D-Bus-backed model. No fetch / parse.
    property string statusText: NetworkModel.statusTextShort()
    property bool wifiIsEnabled: NetworkModel.wifiOn
    property int connectedSignal: NetworkModel.activeWifiSignal
    property bool wifiConnected: NetworkModel.wifiConnected
    property bool ethConnected: NetworkModel.ethConnected

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: netText
            text: root.statusText
            font.pixelSize: Theme.fontPixelSize
            font.family: Theme.fontFamily
            color: Colors.foreground
        }

        Row {
            visible: wifiConnected
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: 4
                delegate: Rectangle {
                    width: 10
                    height: 10
                    color: index < Math.round(connectedSignal / 25)
                           ? Colors.foreground : Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                NetworkModel.setWifiEnabled(!wifiIsEnabled)
            } else {
                Panels.toggle("network")
            }
        }
    }
}