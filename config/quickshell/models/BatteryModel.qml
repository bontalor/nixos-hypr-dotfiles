pragma Singleton

import QtQuick
import Quickshell
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
//   deviceName(d)         human-readable name for a device
//   stateText(d)          human-readable state string
//   selectDevice(path)    pick which device the widget tracks (persisted)
//   profileIndex          int index into `profiles`
//   profiles              array of { name, enumVal, icon }
//   setProfile(index)     switch the active profile by list index

Singleton {
    id: root

    // Percentage thresholds for the low-battery alerts (power/BatteryAlerts)
    // and the bar widget / panel color tint. The warning level is a
    // Settings pref; critical stays fixed below any warning option. Clamp
    // the warning pref to at least critical+1 — if the user picks a value
    // lower than critical, BatteryAlerts's `else if` branch never fires
    // (the critical branch hits first), so the low-battery warning would
    // be silently skipped entirely.
    readonly property int batteryCritical: 10
    readonly property int batteryWarning: Math.max(batteryCritical + 1, PrefStore.batteryWarnLevel)

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
    // Falls back to the first available battery device. selectDevice()
    // writes the pref; the binding keeps this in sync with the store.
    readonly property string selectedNativePath: PrefStore.batteryDevice

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

    // Quickshell's UPower service scales the D-Bus percentage (0-100) down to
    // a 0.0-1.0 fraction, so multiply back by 100.
    readonly property int percentage: root.activeDevice ? Math.round(root.activeDevice.percentage * 100) : -1
    readonly property bool charging: root.activeDevice
        ? root.activeDevice.state === UPowerDeviceState.Charging
        : false

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
        PrefStore.batteryDevice = nativePath
    }

    // --- Power profiles ---
    readonly property var _profileEnum: PowerProfiles.profile

    readonly property int profileIndex: {
        switch (root._profileEnum) {
        case PowerProfile.Performance: return 0
        case PowerProfile.Balanced:    return 1
        case PowerProfile.PowerSaver:  return 2
        default:                       return -1
        }
    }

    // Single source of truth for profile metadata: name, enum value,
    // and icon glyph (shared with the bar via Icon rather than
    // duplicating codepoints). profileIndex/setProfile index into this.
    readonly property var profiles: [
        { name: "Performance", enumVal: 0, icon: Icon.bolt },
        { name: "Balanced",    enumVal: 1, icon: Icon.balance },
        { name: "Power Saver", enumVal: 2, icon: Icon.leaf }
    ]

    function setProfile(index) {
        switch (index) {
        case 0: PowerProfiles.profile = PowerProfile.Performance; break
        case 1: PowerProfiles.profile = PowerProfile.Balanced; break
        case 2: PowerProfiles.profile = PowerProfile.PowerSaver; break
        }
    }
}
