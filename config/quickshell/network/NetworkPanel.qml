import "../theme"
import "../models"
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
        { name: "Configuration" },
        { name: "NetworkManager" }
    ]

    // Live D-Bus-backed state from NetworkModel. No fetch, no parse, no
    // manual refresh relay.
    property var wifiDevices: NetworkModel.wifiDevices
    property var wiredDevices: NetworkModel.wiredDevices
    property bool wifiEnabled: NetworkModel.wifiOn
    property string connectivityState: NetworkModel.connectivity
    property string connectivityLevel: NetworkModel.connectivity // single field now

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

    currentModelLength: function() {
        switch (root.selSection) {
        case 0: return root.wifiEnabled ? root.wifiNetworks.length : 0
        case 1: return root.wiredDevices.length
        case 2: return 2
        case 3: return 2
        default: return 0
        }
    }

    onDeviceActivated: function(idx) {
        switch (root.selSection) {
        case 0: toggleWifiNetwork(idx); break
        case 1: toggleEthernet(idx); break
        case 2: if (idx === 0) setWifiEnabled(!root.wifiEnabled); break
        case 3:
            if (idx === 0) checkConnectivity()
            else if (idx === 1) launchNmtui()
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
        if (dev.connected) dev.disconnect()
        // Reconnecting a wired device isn't exposed by the Quickshell API;
        // nmcli still has it as a fallback for the rare off case.
        else nmcliProc.command = ["nmcli", "device", "connect", dev.name]; nmcliProc.running = true
    }

    function checkConnectivity() { Networking.checkConnectivity() }

    Process {
        id: nmcliProc
        running: false
    }

    function launchNmtui() {
        nmcliProc.command = ["foot", "-e", "nmtui"]
        nmcliProc.running = true
    }

    // ---- Section 0: Wi-Fi list ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 0

        Text {
            width: parent.width
            height: Theme.searchRowHeight
            visible: !root.wifiEnabled
            text: "Wi-Fi is turned off"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            font.pixelSize: Theme.fontPixelSize
            font.family: Theme.fontFamily
        }

        Repeater {
            model: root.wifiNetworks
            visible: root.wifiEnabled

            delegate: Item {
                id: wifiItem
                width: parent.width
                height: root.rowHeight
                property int wifiSignal: modelData.signal || 0

                Rectangle {
                    anchors.fill: parent
                    color: root.inSection && index === root.selDevice ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
                }

                Text {
                    id: wifiLabel
                    text: modelData.ssid
                    anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
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
                                   ? Colors.foreground : Qt.alpha(Colors.foreground, 0.25)
                        }
                    }
                }

                Text {
                    anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    text: {
                        if (modelData.network.stateChanging) {
                            return modelData.network.state === ConnectionState.Connecting
                                ? "Connecting..." : "Disconnecting..."
                        }
                        return modelData.active ? "Connected" : "Off"
                    }
                    color: modelData.active ? Colors.base0b : Qt.alpha(Colors.foreground, Theme.alphaBackground)
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    font.bold: modelData.active
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.inSection) { root.inSection = true; root.selDevice = index }
                        root.toggleWifiNetwork(index)
                    }
                }
            }
        }

        Text {
            width: parent.width
            height: Theme.searchRowHeight
            visible: root.wifiEnabled && root.wifiNetworks.length === 0
            text: "No Wi-Fi networks found"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            font.pixelSize: Theme.fontPixelSize
            font.family: Theme.fontFamily
        }
    }

    // ---- Section 1: Ethernet ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 1

        Repeater {
            model: root.wiredDevices

            delegate: Item {
                width: parent.width
                height: root.rowHeight

                Rectangle {
                    anchors.fill: parent
                    color: root.inSection && index === root.selDevice ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
                }

                Text {
                    id: ethLabel
                    text: modelData.name || "(unnamed)"
                    anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                    width: parent.width * 0.45
                }

                Text {
                    text: modelData.address || (modelData.connected ? "Connected" : "Disconnected")
                    anchors { left: ethLabel.right; leftMargin: Theme.margin; right: ethStatus.left; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: modelData.connected ? Colors.foreground : Qt.alpha(Colors.foreground, Theme.alphaBackground)
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }

                Text {
                    id: ethStatus
                    anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    text: modelData.stateChanging
                        ? (modelData.state === ConnectionState.Disconnecting ? "Disconnecting..." : "Connecting...")
                        : modelData.connected ? "Connected" : "Off"
                    color: modelData.connected ? Colors.base0b : Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    font.bold: modelData.connected
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.inSection) { root.inSection = true; root.selDevice = index }
                        root.toggleEthernet(index)
                    }
                }
            }
        }

        Text {
            width: parent.width
            height: Theme.searchRowHeight
            visible: root.wiredDevices.length === 0
            text: "No Ethernet devices"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            font.pixelSize: Theme.fontPixelSize
            font.family: Theme.fontFamily
        }
    }

    // ---- Section 2: Configuration ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 2

        Text {
            text: "Wi-Fi"
            width: parent.width
            height: 20
            leftPadding: Theme.margin
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            font.pixelSize: Theme.fontPixelSize
            font.family: Theme.fontFamily
            font.bold: true
        }

        Rectangle {
            width: parent.width
            height: root.rowHeight
            color: root.inSection && 0 === root.selDevice ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"

            Text {
                text: "Wi-Fi: " + (root.wifiEnabled ? "On" : "Off")
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                color: Colors.foreground
                font.pixelSize: Theme.fontPixelSize
                font.family: Theme.fontFamily
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.inSection) { root.inSection = true; root.selDevice = 0 }
                    root.setWifiEnabled(!root.wifiEnabled)
                }
            }
        }

        Text {
            text: "Ethernet"
            width: parent.width
            height: 20
            leftPadding: Theme.margin
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            font.pixelSize: Theme.fontPixelSize
            font.family: Theme.fontFamily
            font.bold: true
        }

        Rectangle {
            width: parent.width
            height: root.rowHeight
            color: root.inSection && 2 === root.selDevice ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"

            Text {
                text: "Ethernet: " + (root.wiredDevices.some(function(d) { return d.connected }) ? "Connected" : "Disconnected")
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                color: Colors.foreground
                font.pixelSize: Theme.fontPixelSize
                font.family: Theme.fontFamily
            }
        }
    }

    // ---- Section 3: NetworkManager ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 3

        Rectangle {
            width: parent.width
            height: root.rowHeight
            color: root.inSection && 0 === root.selDevice ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"

            Text {
                text: "Connectivity: " + (root.connectivityState || "--")
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                color: Colors.foreground
                font.pixelSize: Theme.fontPixelSize
                font.family: Theme.fontFamily
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.inSection) { root.inSection = true; root.selDevice = 0 }
                    root.checkConnectivity()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: root.rowHeight
            color: root.inSection && 1 === root.selDevice ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"

            Text {
                text: "nmtui"
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                color: Colors.foreground
                font.pixelSize: Theme.fontPixelSize
                font.family: Theme.fontFamily
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.inSection) { root.inSection = true; root.selDevice = 1 }
                    root.launchNmtui()
                }
            }
        }
    }
}