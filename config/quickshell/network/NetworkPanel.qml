import "../theme"
import "../models"
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking

Panel {
    id: root
    title: "Network Control"
    sections: [
        { name: "Wi-Fi" },
        { name: "Ethernet" },
        { name: "Bluetooth" },
        { name: "Configuration" },
        { name: "NetworkManager" }
    ]

    // --- Named section indices (replace magic numbers) ---
    readonly property int secWifi: 0
    readonly property int secEthernet: 1
    readonly property int secBluetooth: 2
    readonly property int secConfig: 3
    readonly property int secNm: 4

    // Live D-Bus-backed state from NetworkModel. No fetch, no parse, no
    // manual refresh relay.
    property var wifiDevices: NetworkModel.wifiDevices
    property var wiredDevices: NetworkModel.wiredDevices
    property bool wifiEnabled: NetworkModel.wifiOn

    // Aggregated "first wifi device's networks" view — matches the prior UI
    // behaviour (the bar showed a single wifi adapter).
    property var wifiNetworks: {
        var ds = root.wifiDevices
        if (ds.length === 0) return []
        var nets = ds[0].networks ? ds[0].networks.values : []
        var out = []
        for (var i = 0; i < nets.length; i++) {
            var n = nets[i]
            out.push({
                network: n,
                ssid: n.name || "(hidden)",
                signal: Math.round((n.signalStrength || 0) * 100),
                active: n.connected,
                known: n.known,
                // WifiSecurityType enum -> coarse "Open"/"Secured" badge
                secured: n.security !== undefined && n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Unknown
            })
        }
        return out
    }

    // Live BlueZ-backed state from the native Quickshell.Bluetooth
    // service — same no-shell-out approach as NetworkModel for NM.
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter !== null && btAdapter.enabled

    // Discover while the Bluetooth section is on screen (GNOME-style) —
    // no manual scan toggle to forget about. Note BlueZ keeps
    // `discovering` true for a short grace period after the stop call.
    readonly property bool btScanWanted: root.visible && root.selSection === root.secBluetooth && root.btOn
    // Only write on a real change — a redundant stop makes BlueZ warn
    // "No discovery started" (seen on reload).
    onBtScanWantedChanged: {
        if (root.btAdapter && root.btAdapter.discovering !== root.btScanWanted)
            root.btAdapter.discovering = root.btScanWanted
    }

    // A device belongs in "My devices" if BlueZ has any lasting
    // relationship with it: paired/bonded (link keys stored), trusted
    // (we set it on the first connect attempt), or currently connected.
    // Mirrors DankMaterialShell's `paired || trusted` classification.
    function btKnown(dev) { return dev.paired || dev.bonded || dev.trusted || dev.connected }

    // Two lists: known devices ("My devices") and discovered ones
    // (below the scanning header), alphabetical within each. Scan
    // results are limited to devices that advertise a real name
    // (deviceName) — address-only entries are BLE beacon noise. The
    // concatenated btDevices is the flat index space the expandSection
    // keyboard nav (selConfigItem) operates on.
    readonly property var btMyDevices: btFilterSort(true)
    readonly property var btFoundDevices: btFilterSort(false)
    readonly property var btDevices: btMyDevices.concat(btFoundDevices)

    function btFilterSort(known) {
        var raw = Bluetooth.devices ? Bluetooth.devices.values : []
        var out = []
        for (var i = 0; i < raw.length; i++) {
            if (btKnown(raw[i]) !== known) continue
            if (!known && !raw[i].deviceName) continue
            out.push(raw[i])
        }
        out.sort(function(a, b) {
            return (a.name || a.address).localeCompare(b.name || b.address)
        })
        return out
    }

    // The Bluetooth section is the panel's expandable-config section:
    // each device row opens a dropdown of actions (Connect/Disconnect,
    // Forget). Panel's expandSection machinery drives the keyboard nav.
    expandSection: secBluetooth
    configItemCount: function() { return root.btOn ? root.btDevices.length : 0 }
    configProfileCount: function() {
        var dev = root.btDevices[root.selConfigItem]
        return dev ? root.btDeviceOptions(dev).length : 0
    }
    onConfigActivated: btApplyOption(root.selConfigItem, root.selConfigProfile)

    // Dropdown actions for a device. Discovered devices only offer
    // Connect (which pairs implicitly, see btConnectAction); known ones
    // get Connect/Disconnect plus Forget.
    function btDeviceOptions(dev) {
        if (!btKnown(dev)) return [{ name: "Connect", action: "connect" }]
        return [
            { name: dev.connected ? "Disconnect" : "Connect", action: "connect" },
            { name: "Forget", action: "forget" }
        ]
    }

    function btApplyOption(idx, optIdx) {
        var dev = root.btDevices[idx]
        if (!dev) return
        var opt = root.btDeviceOptions(dev)[optIdx]
        if (!opt) return
        if (opt.action === "forget") dev.forget()
        else btConnectAction(dev)
        root.configExpanded = false
    }

    function btConnectAction(dev) {
        if (dev.state === BluetoothDeviceState.Connecting
            || dev.state === BluetoothDeviceState.Disconnecting || dev.pairing) return
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

    // Sublabel for a device row: state plus battery when reported.
    function btStatusText(dev) {
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

    // Shadows Panel.scrollToSelection: the Bluetooth section interleaves
    // the "My devices" / "Scanning for devices..." headers (20px + spacing
    // each, plus the "No paired devices" placeholder when relevant) that
    // the base fixed-stride arithmetic doesn't know about.
    function scrollToSelection() {
        if (root.selSection !== root.secBluetooth) {
            root.scrollToVisible(
                root.headerHeight + root.colSpacing + root.selDevice * (root.rowHeight + root.colSpacing),
                root.rowHeight)
            return
        }
        var paired = root.btMyDevices.length
        var i = root.selConfigItem
        var y = root.headerHeight + root.colSpacing   // section header bar
              + 20 + root.colSpacing                  // "My devices" header
              + i * (root.rowHeight + root.colSpacing)
        if (i >= paired) {
            y += 20 + root.colSpacing                 // "Scanning..." header
            if (paired === 0) y += Theme.searchRowHeight + root.colSpacing  // "No paired devices"
        }
        var h = root.rowHeight
        if (root.configExpanded) {
            y += root.rowHeight + root.selConfigProfile * Theme.searchRowHeight
            h = Theme.searchRowHeight
        }
        root.scrollToVisible(y, h)
    }

    currentModelLength: function() {
        switch (root.selSection) {
        case root.secWifi: return root.wifiEnabled ? root.wifiNetworks.length : 0
        case root.secEthernet: return root.wiredDevices.length
        case root.secConfig: return 2
        case root.secNm: return 1
        default: return 0
        }
    }

    onDeviceActivated: function(idx) {
        switch (root.selSection) {
        case root.secWifi: toggleWifiNetwork(idx); break
        case root.secEthernet: toggleEthernet(idx); break
        case root.secConfig:
            if (idx === 0) setWifiEnabled(!root.wifiEnabled)
            else if (idx === 1 && root.btAdapter) root.btAdapter.enabled = !root.btOn
            break
        case root.secNm:
            if (idx === 0) launchNmtui()
            break
        }
    }

    function setWifiEnabled(val) { NetworkModel.setWifiEnabled(val) }

    function toggleWifiNetwork(idx) {
        var list = root.wifiNetworks
        if (idx >= list.length) return
        var net = list[idx]
        if (net.active) {
            net.network.disconnect()
        } else if (net.secured && !net.known) {
            launchNmtui()
        } else {
            net.network.connect()
        }
    }

    function toggleEthernet(idx) {
        var list = root.wiredDevices
        if (idx >= list.length) return
        var dev = list[idx]
        if (dev.connected) {
            dev.disconnect()
        } else {
            // Reconnecting a wired device isn't exposed by the Quickshell API;
            // nmcli still has it as a fallback for the rare off case.
            // (Braces here are load-bearing — without them `nmcliProc.running
            // = true` fired unconditionally, including on the disconnect branch.)
            nmcliProc.command = ["nmcli", "device", "connect", dev.name]
            nmcliProc.running = true
        }
    }

    Process {
        id: nmcliProc
        running: false
    }

    function launchNmtui() {
        nmcliProc.command = ["foot", "-e", "nmtui"]
        nmcliProc.running = true
    }

    // ---- Wi-Fi list ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secWifi

        EmptyLabel {
            visible: !root.wifiEnabled
            text: "Wi-Fi is turned off"
        }

        Repeater {
            // `visible` on a Repeater doesn't hide its delegates (they're
            // parented to the Column) — gate the model instead.
            model: root.wifiEnabled ? root.wifiNetworks : []

            delegate: PanelRow {
                id: wifiItem
                width: parent.width
                height: root.rowHeight
                property int wifiSignal: modelData.signal || 0
                selected: root.inSection && index === root.selDevice
                onClicked: {
                    if (!root.inSection) { root.inSection = true; root.selDevice = index }
                    root.toggleWifiNetwork(index)
                }

                ThemeText {
                    id: wifiLabel
                    text: modelData.ssid
                    anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    elide: Text.ElideRight
                    width: parent.width * 0.45
                }

                Row {
                    anchors { left: wifiLabel.right; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    height: 10
                    spacing: Theme.margin

                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            width: 10
                            height: 10
                            color: index < Math.round(wifiItem.wifiSignal / 25)
                                   ? Colors.foreground : Qt.alpha(Colors.foreground, Theme.alphaInactive)
                        }
                    }
                }

                ThemeText {
                    anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    text: {
                        if (modelData.network.stateChanging) {
                            return modelData.network.state === ConnectionState.Connecting
                                ? "Connecting..." : "Disconnecting..."
                        }
                        return modelData.active ? "Connected" : "Off"
                    }
                    color: modelData.active ? Colors.base0b : Qt.alpha(Colors.foreground, Theme.alphaBackground)
                    font.bold: modelData.active
                }
            }
        }

        EmptyLabel {
            visible: root.wifiEnabled && root.wifiNetworks.length === 0
            text: "No Wi-Fi networks found"
        }
    }

    // ---- Ethernet ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secEthernet

        Repeater {
            model: root.wiredDevices

            delegate: PanelRow {
                width: parent.width
                height: root.rowHeight
                selected: root.inSection && index === root.selDevice
                onClicked: {
                    if (!root.inSection) { root.inSection = true; root.selDevice = index }
                    root.toggleEthernet(index)
                }

                ThemeText {
                    id: ethLabel
                    text: modelData.name || "(unnamed)"
                    anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    elide: Text.ElideRight
                    width: parent.width * 0.45
                }

                ThemeText {
                    text: modelData.address || (modelData.connected ? "Connected" : "Disconnected")
                    anchors { left: ethLabel.right; leftMargin: Theme.margin; right: ethStatus.left; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: modelData.connected ? Colors.foreground : Qt.alpha(Colors.foreground, Theme.alphaBackground)
                    elide: Text.ElideRight
                }

                ThemeText {
                    id: ethStatus
                    anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    text: modelData.stateChanging
                        ? (modelData.state === ConnectionState.Disconnecting ? "Disconnecting..." : "Connecting...")
                        : modelData.connected ? "Connected" : "Off"
                    color: modelData.connected ? Colors.base0b : Colors.foreground
                    font.bold: modelData.connected
                }
            }
        }

        EmptyLabel {
            visible: root.wiredDevices.length === 0
            text: "No Ethernet devices"
        }
    }

    // Device row + action dropdown, shared by both Bluetooth lists.
    // `flatIndex` is the device's position in the concatenated btDevices
    // (found devices are offset by the paired count).
    component BtDeviceItem: ConfigExpandItem {
        id: btItem
        property var dev
        property int flatIndex

        label: dev.name || dev.deviceName || dev.address
        sublabel: root.btStatusText(dev)
        isSelected: root.inSection && flatIndex === root.selConfigItem
        isExpanded: root.configExpanded && flatIndex === root.selConfigItem
        profileCount: root.btDeviceOptions(dev).length
        panel: root
        itemIndex: flatIndex

        Repeater {
            model: btItem.isExpanded ? root.btDeviceOptions(btItem.dev) : []

            delegate: ConfigProfileRow {
                label: modelData.name
                isSelected: index === root.selConfigProfile
                onClicked: if (root.inSection) root.btApplyOption(btItem.flatIndex, index)
            }
        }
    }

    // ---- Bluetooth ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secBluetooth

        EmptyLabel {
            visible: !root.btAdapter
            text: "No Bluetooth adapter"
        }

        EmptyLabel {
            visible: root.btAdapter && !root.btOn
            text: "Bluetooth is turned off"
        }

        ThemeText {
            visible: root.btOn
            text: "My devices"
            width: parent.width
            height: 20
            leftPadding: Theme.margin
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            font.bold: true
        }

        Repeater {
            model: root.btOn ? root.btMyDevices : []
            delegate: BtDeviceItem { dev: modelData; flatIndex: index }
        }

        EmptyLabel {
            visible: root.btOn && root.btMyDevices.length === 0
            text: "No paired devices"
        }

        ThemeText {
            visible: root.btOn
            text: "Scanning for devices..."
            width: parent.width
            height: 20
            leftPadding: Theme.margin
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            font.bold: true
        }

        Repeater {
            model: root.btOn ? root.btFoundDevices : []
            delegate: BtDeviceItem { dev: modelData; flatIndex: index + root.btMyDevices.length }
        }
    }

    // ---- Configuration ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secConfig

        ThemeText {
            text: "Wi-Fi"
            width: parent.width
            height: 20
            leftPadding: Theme.margin
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            font.bold: true
        }

        PanelRow {
            width: parent.width
            height: root.rowHeight
            selected: root.inSection && 0 === root.selDevice
            onClicked: {
                if (!root.inSection) { root.inSection = true; root.selDevice = 0 }
                root.setWifiEnabled(!root.wifiEnabled)
            }

            ThemeText {
                text: "Wi-Fi: " + (root.wifiEnabled ? "On" : "Off")
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
            }
        }

        ThemeText {
            text: "Ethernet"
            width: parent.width
            height: 20
            leftPadding: Theme.margin
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            font.bold: true
        }

        // Informational only — not selectable (currentModelLength returns
        // 2 for this section: the Wi-Fi toggle above and the Bluetooth
        // toggle below).
        Item {
            width: parent.width
            height: root.rowHeight

            ThemeText {
                text: "Ethernet: " + (root.wiredDevices.some(function(d) { return d.connected }) ? "Connected" : "Disconnected")
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
            }
        }

        ThemeText {
            text: "Bluetooth"
            width: parent.width
            height: 20
            leftPadding: Theme.margin
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            font.bold: true
        }

        PanelRow {
            width: parent.width
            height: root.rowHeight
            selected: root.inSection && 1 === root.selDevice
            onClicked: {
                if (!root.inSection) { root.inSection = true; root.selDevice = 1 }
                if (root.btAdapter) root.btAdapter.enabled = !root.btOn
            }

            ThemeText {
                text: root.btAdapter
                    ? "Bluetooth: " + (root.btOn ? "On" : "Off")
                    : "Bluetooth: no adapter"
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ---- NetworkManager ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secNm

        PanelRow {
            width: parent.width
            height: root.rowHeight
            selected: root.inSection && 0 === root.selDevice
            onClicked: {
                if (!root.inSection) { root.inSection = true; root.selDevice = 0 }
                root.launchNmtui()
            }

            ThemeText {
                text: "nmtui"
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
            }
        }
    }
}
