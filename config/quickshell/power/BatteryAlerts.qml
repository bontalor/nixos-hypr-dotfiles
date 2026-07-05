// Low-battery watcher — fires a shell-internal notification once per
// discharge cycle at BatteryModel.batteryWarning, and again with critical
// urgency (no auto-expire, pops through DND) at BatteryModel.batteryCritical.
// Going back on AC resets both. Lives in shell.qml alongside the bar so
// the model layer stays notification-free.

import "../models"
import "../notifications"
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Services.UPower

Scope {
    id: root

    property bool warned: false
    property bool warnedCritical: false

    readonly property int pct: BatteryModel.percentage
    // Specifically Discharging — `!charging` would also match
    // FullyCharged / PendingCharge on AC.
    readonly property bool discharging: BatteryModel.activeDevice
        ? BatteryModel.activeDevice.state === UPowerDeviceState.Discharging
        : false

    onDischargingChanged: {
        if (root.discharging) root.check()
        else { root.warned = false; root.warnedCritical = false }
    }
    onPctChanged: root.check()

    function check() {
        if (!root.discharging || root.pct < 0) return
        if (root.pct <= BatteryModel.batteryCritical && !root.warnedCritical) {
            root.warnedCritical = true
            NotifDaemon.notify("Battery critical",
                root.pct + "% remaining — plug in now",
                NotificationUrgency.Critical)
        } else if (root.pct <= BatteryModel.batteryWarning && !root.warned) {
            root.warned = true
            NotifDaemon.notify("Battery low", root.pct + "% remaining",
                NotificationUrgency.Normal)
        }
    }
}
