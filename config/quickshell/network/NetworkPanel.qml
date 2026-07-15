// Subprocess dependencies: nmcli (Wi-Fi password connect, Ethernet
// reconnect), <terminal> -e nmtui (NetworkManager TUI).

import "../theme"
import "../components"
import "../models"
import "../util"
import QtQuick
import Quickshell
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

    // autoScroll stays true (default) so Panel.qml fires its onSelDevice /
    // onSelConfigItem / ... scroll handlers; we override `scrollToSelection`
    // below to read the real (variable-height) delegate geometry when a
    // Wi-Fi or Ethernet row's dropdown is open.

    // --- Per-row action dropdown state (Wi-Fi + Ethernet sections) ---
    // Bluetooth keeps the panel-level ConfigExpandItem machinery
    // (expandSection = secBluetooth) since that section's whole UX is
    // dropdown-driven; for Wi-Fi/Ethernet we add an in-row dropdown on
    // top of the existing single-action rows without consuming PanelNav's
    // expandSection slot (one per panel).
    property int expandedRowIdx: -1
    property int selRowAction: 0

    function closeRowDropdown() {
        root.expandedRowIdx = -1
        root.selRowAction = 0
    }
    function toggleRowDropdown(idx) {
        if (root.expandedRowIdx === idx) root.closeRowDropdown()
        else { root.expandedRowIdx = idx; root.selRowAction = 0 }
    }
    function ethActions(dev, idx) {
        if (!dev) return []
        // Only one of Connect/Disconnect makes sense per current state.
        return [{ name: dev.connected ? "Disconnect" : "Connect",
                  action: dev.connected ? "disconnect" : "connect" }]
    }
    function wifiActions(net) {
        if (!net) return []
        if (net.active) return [{ name: "Disconnect", action: "disconnect" }]
        if (net.known) return [
            { name: "Connect",    action: "connect" },
            { name: "Forget",     action: "forget" }
        ]
        // Unknown secured: Connect opens the password row, falls back to
        // nmtui for hidden-SSID networks (handled in doWifiAction below).
        return [{ name: "Connect", action: "connect" }]
    }
    function currentRowActions(idx) {
        switch (root.selSection) {
        case root.secWifi:
            return root.wifiActions(root.wifiNetworks[idx] || null)
        case root.secEthernet:
            return root.ethActions(root.wiredDevices[idx] || null, idx)
        default:
            return []
        }
    }
    function doEthAction(idx, actIdx) {
        var list = root.wiredDevices
        if (idx >= list.length) return
        var dev = list[idx]
        var acts = root.ethActions(dev, idx)
        var act = acts[actIdx]
        if (!act) return
        if (act.action === "disconnect") dev.disconnect()
        else {
            // Reconnecting a wired device isn't exposed by the Quickshell
            // API — nmcli fallback (same caveat as the prior single-click
            // connect; the dropdown is UI-only, behavior is unchanged).
            nmcliProc.command = ["nmcli", "device", "connect", dev.name]
            nmcliProc.running = true
        }
    }
    function doWifiAction(idx, actIdx) {
        var list = root.wifiNetworks
        if (idx >= list.length) return
        var net = list[idx]
        var acts = root.wifiActions(net)
        var act = acts[actIdx]
        if (!act) return
        if (act.action === "connect") {
            if (net.active) return
            if (net.secured && !net.known) {
                var ssid = net.network.name || ""
                if (ssid === "") launchNmtui()
                else root.pwSsid = ssid  // opens the inline password row
            } else {
                net.network.connect()
            }
        } else if (act.action === "disconnect") {
            net.network.disconnect()
        } else if (act.action === "forget") {
            // Quickshell.Networking exposes disconnect() but not
            // forget() of known WifiNetwork profiles in 0.3.0; route
            // via nmcli so the action row is fulfilled.
            var ssid = net.network.name || ""
            if (ssid !== "") {
                nmcliProc.command = ["nmcli", "connection", "delete", ssid]
                nmcliProc.running = true
            }
        }
    }
    function triggerRowAction(idx, actIdx) {
        if (root.selSection === root.secWifi) root.doWifiAction(idx, actIdx)
        else if (root.selSection === root.secEthernet) root.doEthAction(idx, actIdx)
        root.closeRowDropdown()
    }

    // Reset the password row + dropdown on hide or section change. The
    // `sectionChanged` signal (forwarded by Panel.qml from PanelNav)
    // fires alongside `selSection`-property change, so a single handler
    // does both reset paths instead of binding both.
    onVisibleChanged: if (!visible) { root.pwSsid = ""; root.closeRowDropdown() }
    onSectionChanged: { root.pwSsid = ""; root.closeRowDropdown() }

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

    // Live BlueZ-backed state from BluetoothModel — same single-source
    // pattern as NetworkModel/BatteryModel. The bar could surface a BT
    // chip from this singleton without reaching into panel internals.
    readonly property var btAdapter: BluetoothModel.adapter
    readonly property bool btOn: BluetoothModel.on
    readonly property var btMyDevices: BluetoothModel.knownDevices
    readonly property var btFoundDevices: BluetoothModel.foundDevices
    readonly property var btDevices: BluetoothModel.allDevices

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

    // The Bluetooth section is the panel's expandable-config section:
    // each device row opens a dropdown of actions (Connect/Disconnect,
    // Forget). Panel's expandSection machinery drives the keyboard nav.
    expandSection: secBluetooth
    configItemCount: function() { return root.btOn ? root.btDevices.length : 0 }
    configProfileCount: function() {
        var dev = root.btDevices[root.selConfigItem]
        return dev ? BluetoothModel.deviceOptions(dev).length : 0
    }
    onConfigActivated: {
        var dev = root.btDevices[root.selConfigItem]
        if (!dev) return
        var opts = BluetoothModel.deviceOptions(dev)
        var opt = opts[root.selConfigProfile]
        if (!opt) return
        BluetoothModel.applyOption(dev, opt.action)
        root.configExpanded = false
    }

    // scrollToSelection is overridden below — it handles Wi-Fi/Ethernet
    // (variable-height with inline dropdowns) and Bluetooth's sub-header
    // + expandable-profile geometry. Properties selConfigItem etc. are
    // aliased via PanelNav, so Panel.qml's autoScroll-gated handlers
    // route back through the override below.

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
        // Wi-Fi + Ethernet are now driven by per-row dropdowns (see
        // onKeyPressed). Enter still falls through here as a no-op so
        // PanelNav's contract is satisfied for the other sections.
        switch (root.selSection) {
        case root.secConfig:
            if (idx === 0) setWifiEnabled(!root.wifiEnabled)
            else if (idx === 1) BluetoothModel.setOn(!root.btOn)
            break
        case root.secNm:
            if (idx === 0) launchNmtui()
            break
        }
    }

    // Escape backs out of the password row before Panel's default
    // handler would exit the section / close the panel. The Wi-Fi and
    // Ethernet sections additionally get a Tab/Enter/J/K dropdown nav
    // layer; Enter opens the action dropdown instead of immediately
    // connecting/disconnecting, mirroring the rest of the shell's dropdown
    // UX. Bluetooth's dropdown stays on the panel's expandSection machinery.
    onKeyPressed: function(event) {
        if (root.pwSsid !== "" && event.key === Qt.Key_Escape) {
            root.pwSsid = ""
            Qt.callLater(root.forceFocus)
            event.accepted = true
            return
        }

        if (root.inSection
            && (root.selSection === root.secWifi || root.selSection === root.secEthernet)) {
            var open = root.expandedRowIdx === root.selDevice
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Tab:
                if (event.modifiers & Qt.ShiftModifier) {
                    if (open) { root.closeRowDropdown(); event.accepted = true; return }
                    return  // fall through to PanelNav (Shift+Tab climbs out)
                }
                if (open) root.triggerRowAction(root.selDevice, root.selRowAction)
                else root.toggleRowDropdown(root.selDevice)
                event.accepted = true; return
            case Qt.Key_Backtab:
                if (open) { root.closeRowDropdown(); event.accepted = true; return }
                return
            case Qt.Key_Escape:
                if (open) { root.closeRowDropdown(); event.accepted = true; return }
                return  // PanelNav unwinds the section
            case Qt.Key_J:
            case Qt.Key_Down:
                if (open) {
                    root.selRowAction = Scroll.step(
                        root.selRowAction, 1,
                        root.currentRowActions(root.selDevice).length)
                    event.accepted = true; return
                }
                return
            case Qt.Key_K:
            case Qt.Key_Up:
                if (open) {
                    root.selRowAction = Scroll.step(
                        root.selRowAction, -1,
                        root.currentRowActions(root.selDevice).length)
                    event.accepted = true; return
                }
                return
            }
        }
    }

    function setWifiEnabled(val) { NetworkModel.setWifiEnabled(val) }

    // Secured network we're collecting a password for ("" = none). The
    // input lives in a dedicated row above the list — the network rows
    // themselves are recreated whenever the live wifiNetworks binding
    // updates (signal strength changes constantly), which would destroy
    // an in-row TextInput mid-typing.
    property string pwSsid: ""
    onShown: { root.pwSsid = ""; root.closeRowDropdown() }

    // Enter in the password row: nmcli creates the profile and connects.
    // A wrong password or other failure surfaces as a notification via
    // CheckedProcess; the row closes either way.
    function connectWifiPassword(password) {
        if (root.pwSsid === "") return
        nmcliProc.command = ["nmcli", "device", "wifi", "connect", root.pwSsid,
                             "password", password]
        nmcliProc.running = true
        root.pwSsid = ""
        Qt.callLater(root.forceFocus)
    }

    CheckedProcess {
        id: nmcliProc
        running: false
    }

    // Variable-height scroll for the Wi-Fi / Ethernet lists (open
    // dropdowns add Theme.searchRowHeight per action). Mirrors the
    // per-delegate-geometry approach used by NotifHistoryPanel and
    // VolumePanel — overrides Panel.qml's fixed-stride scrollToSelection.
    onSelRowActionChanged: Qt.callLater(root.scrollToSelection)
    onExpandedRowIdxChanged: Qt.callLater(root.scrollToSelection)

    function scrollToSelection() {
        if (!root.inSection) return

        // Wi-Fi / Ethernet: read the real delegate height (variable
        // because of the inline dropdown) rather than the base's
        // fixed-stride rowHeight math.
        if (root.selSection === root.secWifi
            || root.selSection === root.secEthernet) {
            var rep = root.selSection === root.secWifi ? wifiRepeater : ethRepeater
            var col = root.selSection === root.secWifi ? wifiColumn : ethColumn
            if (root.selDevice >= rep.count) return
            var item = rep.itemAt(root.selDevice)
            if (item) {
                root.scrollToVisible(col.y + item.y, item.height)
                if (root.expandedRowIdx === root.selDevice && root.selRowAction >= 0) {
                    var actY = col.y + item.y + root.rowHeight
                              + root.selRowAction * Theme.searchRowHeight
                    root.scrollToVisible(actY, Theme.searchRowHeight)
                }
            }
            return
        }

        // Bluetooth: same geometry the original NetworkPanel override
        // used — original sub-headers, paired/found offset, and the
        // inline profile sub-list of searchRowHeight rows.
        if (root.selSection !== root.secBluetooth) {
            root.scrollToVisible(
                root.headerHeight + root.colSpacing + root.selDevice * (root.rowHeight + root.colSpacing),
                root.rowHeight)
            return
        }
        var paired = root.btMyDevices.length
        var i = root.selConfigItem
        var y = root.headerHeight + root.colSpacing              // section header bar
              + Theme.subHeaderHeight + root.colSpacing          // "My devices" header
              + i * (root.rowHeight + root.colSpacing)
        if (i >= paired) {
            y += Theme.subHeaderHeight + root.colSpacing         // "Scanning..." header
            if (paired === 0) y += Theme.searchRowHeight + root.colSpacing  // "No paired devices"
        }
        var h = root.rowHeight
        if (root.configExpanded) {
            y += root.rowHeight + root.selConfigProfile * Theme.searchRowHeight
            h = Theme.searchRowHeight
        }
        root.scrollToVisible(y, h)
    }

    // Terminal comes from Settings (PrefStore.terminal, default foot);
    // whatever is configured must accept `-e <command>`.
    function launchNmtui() {
        nmcliProc.command = [PrefStore.terminal || "foot", "-e", "nmtui"]
        nmcliProc.running = true
    }

    // ---- Wi-Fi list ----
    Column {
        id: wifiColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secWifi

        EmptyLabel {
            visible: !root.wifiEnabled
            text: "Wi-Fi is turned off"
        }

        // Inline password entry for the network picked in the Wi-Fi
        // Connect action. Enter connects, Escape cancels.
        Rectangle {
            visible: root.pwSsid !== ""
            width: parent.width
            height: root.rowHeight
            color: Qt.alpha(Colors.selected, Theme.alphaSelected)

            ThemeText {
                id: pwLabel
                text: "Password for " + root.pwSsid + ":"
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width * 0.5)
            }

            TextInput {
                id: pwInput
                anchors {
                    left: pwLabel.right; leftMargin: Theme.margin
                    right: parent.right; rightMargin: Theme.margin
                    verticalCenter: parent.verticalCenter
                }
                echoMode: TextInput.Password
                color: Colors.foreground
                font.pixelSize: Theme.fontPixelSize
                font.family: Theme.fontFamily
                onAccepted: root.connectWifiPassword(text)
                // (Re)opening the row always starts a fresh entry.
                onVisibleChanged: {
                    text = ""
                    if (visible) forceActiveFocus()
                }

                ThemeText {
                    text: "enter password…"
                    visible: pwInput.text === ""
                    color: Qt.alpha(Colors.foreground, Theme.alphaDim)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Repeater {
            id: wifiRepeater
            // `visible` on a Repeater doesn't hide its delegates (they're
            // parented to the Column) — gate the model instead.
            model: root.wifiEnabled ? root.wifiNetworks : []

            delegate: DropdownRow {
                id: wifiItem
                width: parent.width
                rowHeight: root.rowHeight
                property int wifiSignal: modelData.signal || 0
                isSelected: root.inSection && index === root.selDevice
                isExpanded: root.expandedRowIdx === index
                selActionIndex: root.expandedRowIdx === index ? root.selRowAction : -1
                actions: root.wifiActions(modelData)

                onToggled: {
                    if (!root.inSection) { root.inSection = true; root.selDevice = index }
                    root.toggleRowDropdown(index)
                }
                onActionTriggered: (idx) => {
                    if (!root.inSection) { root.inSection = true; root.selDevice = index }
                    root.selRowAction = idx
                    root.triggerRowAction(index, idx)
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
                    color: modelData.active ? Colors.success : Qt.alpha(Colors.foreground, Theme.alphaBackground)
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
        id: ethColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secEthernet

        Repeater {
            id: ethRepeater
            model: root.wiredDevices

            delegate: DropdownRow {
                width: parent.width
                rowHeight: root.rowHeight
                isSelected: root.inSection && index === root.selDevice
                isExpanded: root.expandedRowIdx === index
                selActionIndex: root.expandedRowIdx === index ? root.selRowAction : -1
                actions: root.ethActions(modelData, index)

                onToggled: {
                    if (!root.inSection) { root.inSection = true; root.selDevice = index }
                    root.toggleRowDropdown(index)
                }
                onActionTriggered: (idx) => {
                    if (!root.inSection) { root.inSection = true; root.selDevice = index }
                    root.selRowAction = idx
                    root.triggerRowAction(index, idx)
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
                    color: modelData.connected ? Colors.success : Colors.foreground
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
        sublabel: BluetoothModel.statusText(dev)
        isSelected: root.inSection && flatIndex === root.selConfigItem
        isExpanded: root.configExpanded && flatIndex === root.selConfigItem
        profileCount: BluetoothModel.deviceOptions(dev).length
        panel: root
        itemIndex: flatIndex

        Repeater {
            model: btItem.isExpanded ? BluetoothModel.deviceOptions(btItem.dev) : []

            delegate: ConfigProfileRow {
                label: modelData.name
                isSelected: index === root.selConfigProfile
                onClicked: {
                    if (!root.inSection) return
                    var d = root.btDevices[btItem.flatIndex]
                    BluetoothModel.applyOption(d, modelData.action)
                    root.configExpanded = false
                }
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

        SectionSubHeader {
            visible: root.btOn
            text: "My devices"
        }

        Repeater {
            model: root.btOn ? root.btMyDevices : []
            delegate: BtDeviceItem { dev: modelData; flatIndex: index }
        }

        EmptyLabel {
            visible: root.btOn && root.btMyDevices.length === 0
            text: "No paired devices"
        }

        SectionSubHeader {
            visible: root.btOn
            text: "Scanning for devices..."
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

        SectionSubHeader { text: "Wi-Fi" }

        PanelRow {
            width: parent.width
            height: root.rowHeight
            selected: root.inSection && 0 === root.selDevice
            panel: root
            itemIndex: 0
            onClicked: root.setWifiEnabled(!root.wifiEnabled)

            ThemeText {
                text: "Wi-Fi: " + (root.wifiEnabled ? "On" : "Off")
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
            }
        }

        SectionSubHeader { text: "Ethernet" }

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

        SectionSubHeader { text: "Bluetooth" }

        PanelRow {
            width: parent.width
            height: root.rowHeight
            selected: root.inSection && 1 === root.selDevice
            panel: root
            itemIndex: 1
            onClicked: BluetoothModel.setOn(!root.btOn)

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
            panel: root
            itemIndex: 0
            onClicked: root.launchNmtui()

            ThemeText {
                text: "nmtui"
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
            }
        }
    }
}
