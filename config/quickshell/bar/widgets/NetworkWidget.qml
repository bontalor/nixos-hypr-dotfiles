import "../../theme"
import "../../components"
import "../../models"
import QtQuick

WidgetButton {
    id: root

    width: contentRow.width + 2 * Theme.margin

    panel: Panels.network
    acceptRightClick: true

    onRightClicked: mouse => NetworkModel.setWifiEnabled(!NetworkModel.wifiOn)

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.margin

        ThemeText {
            text: NetworkModel.statusTextShort()
        }

        Row {
            visible: NetworkModel.wifiConnected
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: 4
                delegate: Rectangle {
                    width: 4
                    height: 4
                    color: index < Math.round(NetworkModel.activeWifiSignal / 25)
                           ? Colors.foreground : Qt.alpha(Colors.foreground, Theme.alphaInactive)
                }
            }
        }
    }
}
