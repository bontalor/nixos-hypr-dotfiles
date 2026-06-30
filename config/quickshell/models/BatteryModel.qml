pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../util"
import "../theme"

// Centralized power state backed by the native UPower + PowerProfiles
// services. Previously the bar shelled out to `upower -i` and `powerprofilesctl
// get` and parsed their stdout; this singleton reads the live D-Bus
// properties the Quickshell service already has open.
//
// Exposes:
//   batteryDevices        array of all UPower battery devices (mouse, UPS, …)
//   activeDevice          the device the widget shows (user-picked or first)
//   percentage            int 0..100, or -1 if no battery
//   charging              bool (state == Charging)
//   discharging           bool (state == Discharging)
//   onBattery             bool (UPower.onBattery)
//   deviceName(d)         human-readable name for a device
//   stateText(d)          human-readable state string
//   selectDevice(path)    pick which device the widget tracks (persisted)
//   activeProfile         string ("power-saver"/"balanced"/"performance")
//   profileIndex          int index into `profiles`
//   profiles              ListModel of { name, enumVal, icon }
//   setProfile(index)     switch the active profile by list index

Singleton {
    id: root

    // All UPower devices with a real battery — skips line-power supplies
    // and devices whose state is Unknown (no battery). Recomputed when the
    // device list changes.
    readonly property var batteryDevices: {
        var out = []
        var model = UPower.devices
        var devs = model ? model.values : []
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i]
            if (!d || !d.isPresent) continue
            if (d.type === UPowerDeviceType.LinePower) continue
            if (d.state === UPowerDeviceState.Unknown) continue
            out.push(d)
        }
        return out
    }

    // Persisted selection by nativePath (stable across device add/remove).
    // Falls back to the first available battery device. Set via
    // selectDevice() (which persists) or primed at startup by PrefStore.
    property string selectedNativePath: ""

    readonly property var activeDevice: {
        if (root.selectedNativePath) {
            for (var i = 0; i < root.batteryDevices.length; i++) {
                if (root.batteryDevices[i].nativePath === root.selectedNativePath)
                    return root.batteryDevices[i]
            }
        }
        if (root.batteryDevices.length > 0) return root.batteryDevices[0]
        return null
    }

    readonly property bool hasBattery: root.activeDevice !== null

    // Quickshell's UPower service scales the D-Bus percentage (0-100) down to
    // a 0.0-1.0 fraction, so multiply back by 100.
    readonly property int percentage: root.activeDevice ? Math.round(root.activeDevice.percentage * 100) : -1
    readonly property bool charging: root.activeDevice
        ? root.activeDevice.state === UPowerDeviceState.Charging
        : false
    readonly property bool discharging: root.activeDevice
        ? root.activeDevice.state === UPowerDeviceState.Discharging
        : false
    readonly property bool onBattery: UPower.onBattery

    function deviceName(device) {
        if (!device) return ""
        if (device.model) return device.model
        switch (device.type) {
        case UPowerDeviceType.Battery: return "Battery"
        case UPowerDeviceType.Mouse: return "Mouse"
        case UPowerDeviceType.Keyboard: return "Keyboard"
        case UPowerDeviceType.Ups: return "UPS"
        default: return "Battery"
        }
    }

    function stateText(device) {
        if (!device) return ""
        switch (device.state) {
        case UPowerDeviceState.Charging: return "charging"
        case UPowerDeviceState.Discharging: return "discharging"
        case UPowerDeviceState.FullyCharged: return "fully-charged"
        case UPowerDeviceState.Empty: return "empty"
        case UPowerDeviceState.PendingCharge: return "pending-charge"
        case UPowerDeviceState.PendingDischarge: return "pending-discharge"
        default: return "unknown"
        }
    }

    function selectDevice(nativePath) {
        root.selectedNativePath = nativePath
        PrefStore.write("battery", "selected", nativePath)
    }

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

    // Single source of truth for profile metadata: name, enum value,
    // and icon glyph. profileIndex/setProfile index into this list.
    property var profiles: ListModel {
        ListElement { name: "Performance"; enumVal: 0; icon: "\uf0e7" }
        ListElement { name: "Balanced";    enumVal: 1; icon: "\uf0eb" }
        ListElement { name: "Power Saver"; enumVal: 2; icon: "\uf06c" }
    }

    function setProfile(index) {
        switch (index) {
        case 0: PowerProfiles.profile = PowerProfile.Performance; break
        case 1: PowerProfiles.profile = PowerProfile.Balanced; break
        case 2: PowerProfiles.profile = PowerProfile.PowerSaver; break
        }
    }

    Component.onCompleted: {
        PrefStore.read("battery", "selected", function(text) {
            if (text) root.selectedNativePath = text
        })
    }
}
