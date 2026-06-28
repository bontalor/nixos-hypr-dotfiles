import "../../theme"
import "../../models"
import QtQuick

Item {
    id: root
    width: batText.width + 20
    height: 30

    property int batteryPercent: BatteryModel.percentage
    property bool isCharging: BatteryModel.charging
    property string activeProfile: BatteryModel.activeProfile

    property string statusText: computeStatusText(batteryPercent, isCharging, activeProfile)

    function computeStatusText(pct, charging, profile) {
        if (pct < 0) return "Bat ----"

        var profileSymbol = ""
        var p = (profile || "").toLowerCase()
        if (p === "performance") profileSymbol = Icon.bolt
        else if (p === "balanced") profileSymbol = Icon.balance
        else if (p === "power-saver" || p === "power-save" || p === "powersave") profileSymbol = Icon.leaf

        var plugSymbol = charging ? Icon.plug + " " : ""
        var pctStr = String(pct).padStart(3, " ")

        return "Bat " + pctStr + "% " + profileSymbol + " " + plugSymbol
    }

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
    }

    Text {
        id: batText
        anchors.centerIn: parent
        text: root.statusText
        font.pixelSize: Theme.fontPixelSize
        font.family: Theme.fontFamily
        color: {
            if (batteryPercent < 0) return Colors.foreground
            if (batteryPercent <= Theme.batteryCritical) return Colors.base08
            if (batteryPercent <= Theme.batteryWarning) return Colors.base09
            return Colors.foreground
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("battery")
    }
}