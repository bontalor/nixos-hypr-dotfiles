import "../../theme"
import "../../components"
import "../../models"
import "../../util"
import QtQuick

WidgetButton {
    id: root

    property int batteryPercent: BatteryModel.percentage
    property bool isCharging: BatteryModel.charging

    // Glyph comes straight from the shared profiles table — no
    // string-name → icon mapping to keep in sync.
    property string profileSymbol: BatteryModel.profileIndex >= 0
        ? BatteryModel.profiles[BatteryModel.profileIndex].icon : ""

    label: computeStatusText(batteryPercent, isCharging, profileSymbol)
    labelColor: {
        if (batteryPercent < 0) return Colors.foreground
        if (batteryPercent <= BatteryModel.batteryCritical) return Colors.critical
        if (batteryPercent <= BatteryModel.batteryWarning) return Colors.warning
        return Colors.foreground
    }
    panel: Panels.battery

    function computeStatusText(pct, charging, profileSymbol) {
        if (pct < 0) return "Bat ---- " + profileSymbol
        var plugSymbol = charging ? " " + Icon.plug : ""
        return "Bat " + FormatUtil.padNum(pct, 3) + "% " + profileSymbol + plugSymbol
    }
}
