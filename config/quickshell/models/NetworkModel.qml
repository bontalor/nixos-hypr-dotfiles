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
//   connectivity                          full/limited/portal/none/unknown
//   wifiDevices                           filtered list of WifiDevice
//   wiredDevices                          filtered list of WiredDevice
//   wifiConnected / ethConnected          computed booleans
//   activeNetworkSSID                     SSID of the currently active
//                                         WifiNetwork, or "" if none
//   activeWifiSignal                      0..100
//   apiDevices()                          raw Networking.devices for panels
//
// Signal subscriptions are entirely the service's responsibility; we
// don't subscribe to anything from the shell side.

Singleton {
    id: root

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    property bool wifiOn: wifiEnabled && wifiHardwareEnabled

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

    readonly property var wifiDevices: {
        var out = []
        for (var i = 0; i < root.devices.length; i++) {
            var d = root.devices[i]
            if (d.type === DeviceType.Wifi) out.push(d)
        }
        return out
    }

    readonly property var wiredDevices: {
        var out = []
        for (var i = 0; i < root.devices.length; i++) {
            var d = root.devices[i]
            if (d.type === DeviceType.Wired) out.push(d)
        }
        return out
    }

    readonly property bool wifiConnected: {
        var ds = root.wifiDevices
        for (var i = 0; i < ds.length; i++) {
            if (ds[i].connected) return true
        }
        return false
    }

    readonly property bool ethConnected: {
        var ds = root.wiredDevices
        for (var i = 0; i < ds.length; i++) {
            if (ds[i].connected) return true
        }
        return false
    }

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

    // Helper for the bar chip status string
    function statusTextShort() {
        if (root.wifiConnected) return "WiFi On"
        if (root.ethConnected) return "Eth On"
        return "Net ----"
    }
}