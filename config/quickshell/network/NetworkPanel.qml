// Subprocess dependencies: nmcli (Wi-Fi password connect, Ethernet
// reconnect), <terminal> -e nmtui (NetworkManager TUI).

pragma ComponentBehavior: Bound

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

    // --- Per-row action dropdown state (Wi-Fi + Ethernet + Configuration +
    // NetworkManager sections) ---
    // Bluetooth keeps the panel-level ConfigExpandItem machinery
    // (expandSection = secBluetooth) since that section's whole UX is
    // dropdown-driven; the other four sections share DropdownState
    // (state + close/toggle/trigger + keyboard nav) and only supply
    // per-section rowActions(idx) + triggerAction(idx, actIdx).
    DropdownState {
        id: dropdown
        rowActions: function(idx) { return root.currentRowActions(idx) }
        // Hoisted state-stomp: dropdown.toggle/trigger set
        // `inSection = true; selDevice = idx` via this callback,
        // so each DropdownRow delegate below just calls
        // `root.toggleRowDropdown` / `root.triggerRowAction`.
        selectRow: function(idx) { root.selectRow(idx) }
        triggerAction: function(idx, actIdx) {
            if (root.selSection === root.secWifi) root.doWifiAction(idx, actIdx)
            else if (root.selSection === root.secEthernet) root.doEthAction(idx, actIdx)
            else if (root.selSection === root.secConfig) root.doConfigToggleAction(idx, actIdx)
            else if (root.selSection === root.secNm) root.doNmAction(idx, actIdx)
        }
    }

    // Aliases preserved so existing delegate bindings to
    // `root.expandedRowIdx` / `root.selRowAction` and the close/toggle/
    // trigger helper functions keep working.
    property int expandedRowIdx: dropdown.expandedRowIdx
    property int selRowAction: dropdown.selRowAction
    function closeRowDropdown() { dropdown.close() }
    function toggleRowDropdown(idx) { dropdown.toggle(idx) }
    function triggerRowAction(idx, actIdx) { dropdown.trigger(idx, actIdx) }

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
        case root.secConfig:
            return root.configToggleActions(idx)
        case root.secNm:
            return root.nmActions(idx)
        default:
            return []
        }
    }
    // Single-action dropdowns for the Configuration toggles and the
    // NetworkManager "Open nmtui" row — the row header reads the live
    // state ("Wi-Fi: On" / "Bluetooth: Off"); the dropdown's lone action
    // toggles or opens.
    function configToggleActions(idx) {
        switch (idx) {
        case 0:
            return [{ name: root.wifiEnabled ? "Disable Wi-Fi" : "Enable Wi-Fi",
                      action: "toggle-wifi" }]
        case 1:
            return [{ name: root.btAdapter ? (root.btOn ? "Disable Bluetooth" : "Enable Bluetooth")
                                           : "Bluetooth: no adapter",
                      action: "toggle-bt" }]
        default:
            return []
        }
    }
    function nmActions(idx) {
        if (idx === 0) return [{ name: "Open nmtui", action: "nmtui" }]
        return []
    }
    function doConfigToggleAction(idx, actIdx) {
        var acts = root.configToggleActions(idx)
        var act = acts[actIdx]
        if (!act) return
        if (act.action === "toggle-wifi") root.setWifiEnabled(!root.wifiEnabled)
        else if (act.action === "toggle-bt") BluetoothModel.setOn(!root.btOn)
    }
    function doNmAction(idx, actIdx) {
        var acts = root.nmActions(idx)
        var act = acts[actIdx]
        if (!act) return
        if (act.action === "nmtui") root.launchNmtui()
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
            ethConnectProc.command = ["nmcli", "device", "connect", dev.name]
            ethConnectProc.running = true
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
                wifiForgetProc.command = ["nmcli", "connection", "delete", ssid]
                wifiForgetProc.running = true
            }
        }
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
        // Every clickable section (Wi-Fi, Ethernet, Configuration, NM)
        // is dropdown-driven; onKeyPressed intercepts Enter/Tab to open
        // the action list, so this is a no-op kept only to satisfy
        // PanelNav's contract.
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
            && (root.selSection === root.secWifi
                || root.selSection === root.secEthernet
                || root.selSection === root.secConfig
                || root.selSection === root.secNm)) {
                if (dropdown.handleKey(event, root.selDevice)) return
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
    //
    // The password is written to a mktemp'd 0600 file and passed via
    // `secret-file` instead of an argv `password <pw>` arg — the old
    // form leaked the secret into /proc/<pid>/cmdline and any audit
    // log of the spawn. Requires NetworkManager 1.46+ (the `secret-file`
    // flag was added there). On older NM the failure surfaces as a
    // normal nmcli exit-1; the script always removes the temp file
    // regardless of exit, so no secret lingers on disk.
    function connectWifiPassword(password) {
        if (root.pwSsid === "") return
        wifiConnectProc.command = ["sh", "-c",
            'f=$(mktemp -t qs-wifi-pw.XXXXXX) || exit 1; ' +
            'chmod 600 "$f"; ' +
            'printf "%s\n" "$1" > "$f"; ' +
            'nmcli --wait 30 device wifi connect "$2" secret-file "$f"; ' +
            's=$?; rm -f "$f"; exit $s',
            "sh", password, root.pwSsid]
        wifiConnectProc.running = true
        root.pwSsid = ""
        Qt.callLater(root.forceFocus)
    }

    // One CheckedProcess per nmcli job — the previous design shared a
    // single Process for connect/delete/wifi-connect/launch terminal,
    // which meant launching nmtui (long-lived) blocked every Wi-Fi
    // action and reassigning `command` mid-flight dropped pending work.
    CheckedProcess {
        id: ethConnectProc
        label: "nmcli device connect"
        running: false
    }
    CheckedProcess {
        id: wifiForgetProc
        label: "nmcli connection delete"
        running: false
    }
    CheckedProcess {
        id: wifiConnectProc
        label: "nmcli wifi connect"
        running: false
    }

    // Long-lived terminal — separate plain Process so its lifetime is
    // not coupled to nmcli completion. No CheckedProcess wrapper: a
    // non-zero terminal exit (user closes window with Ctrl-C) would
    // spuriously notify "command failed".
    Process {
        id: nmtuiProc
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

        // Wi-Fi / Ethernet / Configuration / NetworkManager: read the real
        // delegate height (variable because of the inline dropdown)
        // rather than the base's fixed-stride rowHeight math.
        // Configuration has no Repeater (two statically-declared
        // DropdownRows), so its lookup mirrors the section's column base
        // and the clicked dropdown row index via child indexes.
        if (root.selSection === root.secWifi
            || root.selSection === root.secEthernet
            || root.selSection === root.secConfig
            || root.selSection === root.secNm) {
            var rep, col
            if (root.selSection === root.secWifi) { rep = wifiRepeater; col = wifiColumn }
            else if (root.selSection === root.secEthernet) { rep = ethRepeater; col = ethColumn }
            else if (root.selSection === root.secConfig) { rep = null; col = configColumn }
            else { rep = null; col = nmColumn }
            if (rep) {
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
            } else {
                // Static-declared DropdownRows — locate by section-relative
                // child index: configColumn children include SectionSubHeader
                // rows we must skip; nmColumn has just the single row.
                var childIdx = root.selDevice
                if (root.selSection === root.secConfig) {
                    // Children order: [SectionSubHeader, DropdownRow(0),
                    // SectionSubHeader, Item(eth status), SectionSubHeader,
                    // DropdownRow(1)] — selDevice 0 -> child 1, selDevice 1 -> child 5.
                    childIdx = root.selDevice === 0 ? 1 : 5
                }
                var target = col.children[childIdx]
                if (target) {
                    root.scrollToVisible(col.y + target.y, target.height)
                    if (root.expandedRowIdx === root.selDevice && root.selRowAction >= 0) {
                        var actY2 = col.y + target.y + root.rowHeight
                                   + root.selRowAction * Theme.searchRowHeight
                        root.scrollToVisible(actY2, Theme.searchRowHeight)
                    }
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
        nmtuiProc.command = [PrefStore.terminal || "foot", "-e", "nmtui"]
        nmtuiProc.running = true
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
                required property var modelData
                required property int index
                width: parent.width
                rowHeight: root.rowHeight
                property int wifiSignal: wifiItem.modelData.signal || 0
                isSelected: root.inSection && index === root.selDevice
                isExpanded: root.expandedRowIdx === index
                selActionIndex: root.expandedRowIdx === index ? root.selRowAction : -1
                actions: root.wifiActions(modelData)

                onToggled: root.toggleRowDropdown(index)
                onActionTriggered: (idx) => root.triggerRowAction(index, idx)

                ThemeText {
                    id: wifiLabel
                    text: wifiItem.modelData.ssid
                    anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    elide: Text.ElideRight
                    width: parent.width * 0.45
                }

                Row {
                    anchors { left: wifiLabel.right; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    height: Theme.meterHeight
                    spacing: Theme.margin

                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: Theme.meterHeight
                            height: Theme.meterHeight
                            color: index < Math.round(wifiItem.wifiSignal / 25)
                                   ? Colors.foreground : Qt.alpha(Colors.foreground, Theme.alphaInactive)
                        }
                    }
                }

                ThemeText {
                    anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    text: {
                        if (wifiItem.modelData.network.stateChanging) {
                            return wifiItem.modelData.network.state === ConnectionState.Connecting
                                ? "Connecting..." : "Disconnecting..."
                        }
                        return wifiItem.modelData.active ? "Connected" : "Off"
                    }
                    color: wifiItem.modelData.active ? Colors.success : Qt.alpha(Colors.foreground, Theme.alphaBackground)
                    font.bold: wifiItem.modelData.active
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
                id: ethRow
                required property var modelData
                required property int index
                width: parent.width
                rowHeight: root.rowHeight
                isSelected: root.inSection && index === root.selDevice
                isExpanded: root.expandedRowIdx === index
                selActionIndex: root.expandedRowIdx === index ? root.selRowAction : -1
                actions: root.ethActions(modelData, index)

                onToggled: root.toggleRowDropdown(index)
                onActionTriggered: (idx) => root.triggerRowAction(index, idx)

                ThemeText {
                    id: ethLabel
                    text: ethRow.modelData.name || "(unnamed)"
                    anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    elide: Text.ElideRight
                    width: parent.width * 0.45
                }

                ThemeText {
                    text: ethRow.modelData.address || (ethRow.modelData.connected ? "Connected" : "Disconnected")
                    anchors { left: ethLabel.right; leftMargin: Theme.margin; right: ethStatus.left; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: ethRow.modelData.connected ? Colors.foreground : Qt.alpha(Colors.foreground, Theme.alphaBackground)
                    elide: Text.ElideRight
                }

                ThemeText {
                    id: ethStatus
                    anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    text: ethRow.modelData.stateChanging
                        ? (ethRow.modelData.state === ConnectionState.Disconnecting ? "Disconnecting..." : "Connecting...")
                        : ethRow.modelData.connected ? "Connected" : "Off"
                    color: ethRow.modelData.connected ? Colors.success : Colors.foreground
                    font.bold: ethRow.modelData.connected
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
        required property var modelData
        required property int index
        // Outer Repeater injects modelData (the BtDevice dict) and index.
        // Wire them into this component's dev + flatIndex defaults; the
        // outer `delegate: BtDeviceItem {…}` blocks need only override
        // flatIndex for the found-devices Repeater (which offsets).
        property var dev: btItem.modelData
        property int flatIndex: btItem.index

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
                id: btProfileRow
                required property var modelData
                required property int index
                label: btProfileRow.modelData.name
                isSelected: btProfileRow.index === root.selConfigProfile
                onClicked: {
                    if (!root.inSection) return
                    var d = root.btDevices[btItem.flatIndex]
                    BluetoothModel.applyOption(d, btProfileRow.modelData.action)
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
            delegate: BtDeviceItem { }
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
            delegate: BtDeviceItem { flatIndex: index + root.btMyDevices.length }
        }
    }

    // ---- Configuration ----
    Column {
        id: configColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secConfig

        SectionSubHeader { text: "Wi-Fi" }

        DropdownRow {
            width: parent.width
            rowHeight: root.rowHeight
            isSelected: root.inSection && 0 === root.selDevice
            isExpanded: root.expandedRowIdx === 0
            selActionIndex: root.expandedRowIdx === 0 ? root.selRowAction : -1
            actions: root.configToggleActions(0)

            onToggled: root.toggleRowDropdown(0)
            onActionTriggered: (idx) => root.triggerRowAction(0, idx)

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

        DropdownRow {
            width: parent.width
            rowHeight: root.rowHeight
            isSelected: root.inSection && 1 === root.selDevice
            isExpanded: root.expandedRowIdx === 1
            selActionIndex: root.expandedRowIdx === 1 ? root.selRowAction : -1
            actions: root.configToggleActions(1)

            onToggled: root.toggleRowDropdown(1)
            onActionTriggered: (idx) => root.triggerRowAction(1, idx)

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
        id: nmColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secNm

        DropdownRow {
            width: parent.width
            rowHeight: root.rowHeight
            isSelected: root.inSection && 0 === root.selDevice
            isExpanded: root.expandedRowIdx === 0
            selActionIndex: root.expandedRowIdx === 0 ? root.selRowAction : -1
            actions: root.nmActions(0)

            onToggled: root.toggleRowDropdown(0)
            onActionTriggered: (idx) => root.triggerRowAction(0, idx)

            ThemeText {
                text: "nmtui"
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
            }
        }
    }
}
