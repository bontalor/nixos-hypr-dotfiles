pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Centralized power state backed by the native UPower + PowerProfiles
// services. Previously the bar shelled out to `upower -i` and `powerprofilesctl
// get` and parsed their stdout; this singleton reads the live D-Bus
// properties the Quickshell service already has open.
//
// Exposes:
//   percentage            int 0..100, or -1 if no displayDevice
//   charging              bool (state == Charging)
//   discharging           bool (state == Discharging)
//   onBattery             bool (UPower.onBattery)
//   activeProfile         string ("power-saver"/"balanced"/"performance")
//   profileIndex          int index into `profiles`
//   profiles              ListModel of { name, enum, icon }
//   setProfile(name)      switch the active profile
//
// `profiles` is a ListModel (not a JS array) so views can use index-based
// access without the `.slice()` reassign trick other panels use to force
// binding re-eval.

Singleton {
    id: root

    readonly property var displayDevice: UPower.displayDevice

    readonly property int percentage: displayDevice ? Math.round(displayDevice.percentage) : -1
    readonly property bool charging: displayDevice
        ? displayDevice.state === UPowerDeviceState.Charging
        : false
    readonly property bool discharging: displayDevice
        ? displayDevice.state === UPowerDeviceState.Discharging
        : false
    readonly property bool onBattery: UPower.onBattery

    // --- Power profiles ---
    readonly property var _profileEnum: PowerProfiles.profile

    readonly property string activeProfile: {
        switch (root._profileEnum) {
        case PowerProfile.Performance: return "performance"
        case PowerProfile.Balanced:    return "balanced"
        case PowerProfile.PowerSaver:  return "power-saver"
        default:                       return ""
        }
    }

    readonly property int profileIndex: {
        switch (root._profileEnum) {
        case PowerProfile.Performance: return 0
        case PowerProfile.Balanced:    return 1
        case PowerProfile.PowerSaver:  return 2
        default:                       return -1
        }
    }

    property var profiles: ListModel {
        ListElement { name: "Performance"; enumVal: 0; icon: "\uf0e7" }
        ListElement { name: "Balanced";    enumVal: 1; icon: "\uf0eb" }
        ListElement { name: "Power Saver"; enumVal: 2; icon: "\uf06c" }
    }

    function setProfile(name) {
        var lc = (name || "").toLowerCase()
        if (lc === "performance")        PowerProfiles.profile = PowerProfile.Performance
        else if (lc === "balanced")      PowerProfiles.profile = PowerProfile.Balanced
        else if (lc === "power-saver"
              || lc === "power-save"
              || lc === "powersaver")    PowerProfiles.profile = PowerProfile.PowerSaver
    }
}