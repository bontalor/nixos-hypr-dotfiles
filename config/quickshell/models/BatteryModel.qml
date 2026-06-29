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
//   percentage            int 0..100, or -1 if no battery
//   charging              bool (state == Charging)
//   discharging           bool (state == Discharging)
//   onBattery             bool (UPower.onBattery)
//   activeProfile         string ("power-saver"/"balanced"/"performance")
//   profileIndex          int index into `profiles`
//   profiles              ListModel of { name, enumVal, icon }
//   setProfile(index)     switch the active profile by list index
//
// `profiles` is a ListModel (not a JS array) so views can use index-based
// access without the `.slice()` reassign trick other panels use to force
// binding re-eval.

Singleton {
    id: root

    readonly property var displayDevice: UPower.displayDevice

    // UPower's displayDevice is a composite: on a laptop it's the battery,
    // on a desktop it's the line-power supply (type=LinePower, percentage=0,
    // state=Unknown). Gate on type==Battery so a batteryless machine reports
    // -1 / false instead of "0% unknown".
    readonly property bool hasBattery: displayDevice
        ? displayDevice.type === UPowerDeviceType.Battery
        : false

    readonly property int percentage: hasBattery ? Math.round(displayDevice.percentage) : -1
    readonly property bool charging: hasBattery
        ? displayDevice.state === UPowerDeviceState.Charging
        : false
    readonly property bool discharging: hasBattery
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

    // Map a list index (matching `profiles`/`profileIndex`) back to the
    // PowerProfile enum. The enum values don't match the list order
    // (PowerSaver=0, Balanced=1, Performance=2 vs list 0,1,2), so a direct
    // assignment isn't possible.
    function setProfile(index) {
        switch (index) {
        case 0: PowerProfiles.profile = PowerProfile.Performance; break
        case 1: PowerProfiles.profile = PowerProfile.Balanced; break
        case 2: PowerProfiles.profile = PowerProfile.PowerSaver; break
        }
    }
}
