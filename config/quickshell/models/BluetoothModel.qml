pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Centralized Bluetooth state backed by the native Quickshell.Bluetooth
// service (BlueZ over D-Bus). Mirrors the NetworkModel / BatteryModel
// pattern — pure live state, no shelling out.
//
// Exposes:
//   adapter              BlueZ default adapter (Bluetooth.defaultAdapter)
//   on                   adapter present and enabled
//   setOn(bool)          toggle adapter (no-op when absent)
//   devices              raw Bluetooth.devices.values, [] safe
//   knownDevices         paired/bonded/trusted/connected (sort by name)
//   foundDevices         scan results with a real deviceName, excluding known
//   allDevices           knownDevices ++ foundDevices (flat index space
//                        for NetworkPanel's expandSection keyboard nav)
//   isKnown(dev)         classification predicate (paired|bonded|trusted|connected)
//   deviceOptions(dev)   dropdown action list for a device
//   applyOption(dev, opt)  execute "connect"/"forget" — connect toggles
//                          connected state and trusts on first connect
//   statusText(dev)      "Connected · 75%" etc. for the row sublabel

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter !== null && adapter.enabled

    function setOn(val) { if (root.adapter) root.adapter.enabled = val }

    readonly property var devices: {
        var raw = Bluetooth.devices
        return raw && raw.values ? raw.values : []
    }

    function isKnown(dev) {
        return dev.paired || dev.bonded || dev.trusted || dev.connected
    }

    function _filterSort(known) {
        var raw = root.devices
        var out = []
        for (var i = 0; i < raw.length; i++) {
            if (root.isKnown(raw[i]) !== known) continue
            // Found devices with no name are BLE beacon noise — skip.
            if (!known && !raw[i].deviceName) continue
            out.push(raw[i])
        }
        out.sort(function(a, b) {
            return (a.name || a.address).localeCompare(b.name || b.address)
        })
        return out
    }

    readonly property var knownDevices: root._filterSort(true)
    readonly property var foundDevices: root._filterSort(false)
    readonly property var allDevices: root.knownDevices.concat(root.foundDevices)

    function deviceOptions(dev) {
        if (!dev) return []
        if (!root.isKnown(dev)) return [{ name: "Connect", action: "connect" }]
        return [
            { name: dev.connected ? "Disconnect" : "Connect", action: "connect" },
            { name: "Forget", action: "forget" }
        ]
    }

    function applyOption(dev, optName) {
        if (!dev) return
        if (optName === "forget") { dev.forget(); return }
        if (optName !== "connect") return
        // Toggling connect/disconnect; bail during a transition.
        if (dev.state === BluetoothDeviceState.Connecting
            || dev.state === BluetoothDeviceState.Disconnecting
            || dev.pairing) return
        if (dev.connected) {
            dev.disconnect()
        } else {
            // Never pair() here: BlueZ's Connect() pairs implicitly when
            // a profile requires it and the bond persists, whereas the
            // explicit Pair() call needs a registered agent to answer
            // authorization requests and doesn't connect afterwards —
            // agent-less it leaves the device connected-but-unbonded.
            // Trusted first so the device may reconnect on its own.
            // (Same flow as DankMaterialShell and caelestia; passkey-
            // confirmation devices still need a one-time bluetoothctl
            // pairing since the shell registers no agent.)
            dev.trusted = true
            dev.connect()
        }
    }

    function statusText(dev) {
        if (!dev) return ""
        var status
        switch (dev.state) {
        case BluetoothDeviceState.Connecting: status = "Connecting..."; break
        case BluetoothDeviceState.Disconnecting: status = "Disconnecting..."; break
        default:
            status = dev.pairing ? "Pairing..."
                : dev.connected ? "Connected"
                : dev.paired ? "Paired" : ""
        }
        if (dev.batteryAvailable) {
            var bat = Math.round(dev.battery * 100) + "%"
            status = status ? status + " · " + bat : bat
        }
        return status
    }
}