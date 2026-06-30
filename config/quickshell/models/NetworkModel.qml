pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Centralized network state backed by the native Quickshell.Networking
// service (which wraps NetworkManager's D-Bus interface directly).
//
// Previously the bar shelled out to `nmcli -t` and parsed text every
// poll. This singleton consumes the same data via live QObject
// properties that already fire on D-Bus property changes.
//
// Exposes the relevant subsets from `Networking` so widgets and panels
// don't need to know about Quickshell.Networking directly:
//   wifiEnabled / setWifiEnabled(bool)
//   wifiHardwareEnabled
//   wifiOn                               wifiEnabled && wifiHardwareEnabled
//   connectivity                          full/limited/portal/none/unknown
//   devices                               raw Networking.devices for panels
//   wifiDevices                           filtered list of WifiDevice
//   wiredDevices                          filtered list of WiredDevice
//   wifiConnected / ethConnected          computed booleans
//   activeNetworkSSID                     SSID of the currently active
//                                         WifiNetwork, or "" if none
//   activeWifiSignal                      0..100
//   statusTextShort()                     bar chip status string
//
// Signal subscriptions are entirely the service's responsibility; we
// don't subscribe to anything from the shell side.

Singleton {
    id: root

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool wifiOn: wifiEnabled && wifiHardwareEnabled

    function setWifiEnabled(on) { Networking.wifiEnabled = on }

    readonly property string connectivity: {
        switch (Networking.connectivity) {
        case NetworkConnectivity.Full:    return "full"
        case NetworkConnectivity.Limited: return "limited"
        case NetworkConnectivity.Portal:  return "portal"
        case NetworkConnectivity.None:    return "none"
        default:                          return "unknown"
        }
    }

    readonly property var devices: Networking.devices ? Networking.devices.values : []

    function devicesOfType(type) {
        var out = []
        var ds = root.devices
        for (var i = 0; i < ds.length; i++) {
            if (ds[i].type === type) out.push(ds[i])
        }
        return out
    }

    readonly property var wifiDevices: devicesOfType(DeviceType.Wifi)
    readonly property var wiredDevices: devicesOfType(DeviceType.Wired)

    function anyConnected(devices) {
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].connected) return true
        }
        return false
    }

    readonly property bool wifiConnected: anyConnected(root.wifiDevices)
    readonly property bool ethConnected: anyConnected(root.wiredDevices)

    // The active WifiNetwork for the bar chip display.
    readonly property var activeWifiNetwork: {
        var ds = root.wifiDevices
        for (var i = 0; i < ds.length; i++) {
            var nets = ds[i].networks ? ds[i].networks.values : []
            for (var j = 0; j < nets.length; j++) {
                if (nets[j].connected) return nets[j]
            }
        }
        return null
    }

    readonly property string activeNetworkSSID: root.activeWifiNetwork ? (root.activeWifiNetwork.name || "") : ""

    // WifiNetwork.signalStrength is a normalized 0..1 — match the bar's old
    // 0..100 / 25 -> 4 bars mapping.
    readonly property int activeWifiSignal: root.activeWifiNetwork
        ? Math.round((root.activeWifiNetwork.signalStrength || 0) * 100)
        : 0

    function statusTextShort() {
        if (root.wifiConnected) return "WiFi On"
        if (root.ethConnected) return "Eth On"
        return "Net ----"
    }
}
