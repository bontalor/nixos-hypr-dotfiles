import "../../theme"
import "../../models"
import QtQuick

WidgetButton {
    id: root

    width: contentRow.width + 2 * Theme.margin

    // Direct bindings to the D-Bus-backed model. No fetch / parse.
    property string statusText: NetworkModel.statusTextShort()
    property bool wifiIsEnabled: NetworkModel.wifiOn
    property int connectedSignal: NetworkModel.activeWifiSignal
    property bool wifiConnected: NetworkModel.wifiConnected
    property bool ethConnected: NetworkModel.ethConnected

    panel: Panels.network
    acceptRightClick: true

    onRightClicked: mouse => NetworkModel.setWifiEnabled(!root.wifiIsEnabled)

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.margin

        Text {
            text: root.statusText
            font.pixelSize: Theme.fontPixelSize
            font.family: Theme.fontFamily
            color: Colors.foreground
        }

        Row {
            visible: root.wifiConnected
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: 4
                delegate: Rectangle {
                    width: 4
                    height: 4
                    color: index < Math.round(root.connectedSignal / 25)
                           ? Colors.foreground : Qt.alpha(Colors.foreground, 0.25)
                }
            }
        }
    }
}
