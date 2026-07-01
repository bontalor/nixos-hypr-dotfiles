import "../../theme"
import "../../models"
import "../../util"
import QtQuick

WidgetButton {
    id: root

    property int batteryPercent: BatteryModel.percentage
    property bool isCharging: BatteryModel.charging
    property string activeProfile: BatteryModel.activeProfile

    label: computeStatusText(batteryPercent, isCharging, activeProfile)
    labelColor: {
        if (batteryPercent < 0) return Colors.foreground
        if (batteryPercent <= Theme.batteryCritical) return Colors.critical
        if (batteryPercent <= Theme.batteryWarning) return Colors.warning
        return Colors.foreground
    }
    panel: Panels.battery

    function computeStatusText(pct, charging, profile) {
        var profileSymbol = ""
        var p = (profile || "").toLowerCase()
        if (p === "performance") profileSymbol = Icon.bolt
        else if (p === "balanced") profileSymbol = Icon.balance
        else if (p === "power-saver") profileSymbol = Icon.leaf

        if (pct < 0) return "Bat ---- " + profileSymbol

        var plugSymbol = charging ? Icon.plug + " " : ""
        var pctStr = FormatUtil.padNum(pct, 3)

        return "Bat " + pctStr + "% " + profileSymbol + " " + plugSymbol
    }
}
