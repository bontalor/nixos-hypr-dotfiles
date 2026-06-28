import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io

Panel {
    id: root
    title: "Network Control"
    sections: [
        { name: "Wi-Fi" },
        { name: "Ethernet" },
        { name: "Configuration" },
        { name: "NetworkManager" }
    ]

    IpcHandler {
        target: "refresh-network-panel"
        function refresh(): void { if (root.visible) root.runFetch(true) }
    }

    property string rawText: ""
    property var parsedData: parseAll(rawText)

    property var wifiNetworks: parsedData.wifiNetworks
    property var ethernetDevices: parsedData.ethernetDevices
    property bool wifiEnabled: parsedData.wifiEnabled
    property string wifiDeviceName: parsedData.wifiDeviceName
    property string connectivityState: parsedData.connectivityState
    property string connectivityLevel: parsedData.connectivityLevel
    property var savedConnections: parsedData.savedConnections

    property string connectingSsid: ""
    property string disconnectingSsid: ""
    property string pendingEthDevice: ""

    currentModelLength: function() {
        switch (root.selSection) {
        case 0: return root.wifiEnabled ? root.wifiNetworks.length : 0
        case 1: return root.ethernetDevices.length
        case 2: return 2
        case 3: return 2
        default: return 0
        }
    }

    onShown: runFetch(true)
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

    function parseAll(text) {
        var wifis = [], eths = [], savedCons = []
        var wifiOn = false, devName = "", connState = "", connLevel = ""

        var sections = text.split("###")
        for (var si = 0; si < sections.length; si++) {
            var sec = sections[si]
            if (sec.indexOf("DEVICES\n") === 0) {
                var body = sec.substring(8).trim()
                if (body) {
                    var lines = body.split("\n")
                    for (var i = 0; i < lines.length; i++) {
                        var parts = lines[i].split(":")
                        var t = parts[1]
                        if (t === "wifi") {
                            devName = parts[0]
                        } else if (t === "ethernet") {
                            var st = parts[2].split(" ")[0]
                            var conn = parts.slice(3).join(":")
                            eths.push({ name: parts[0], type: t, state: st, connection: conn })
                        }
                    }
                }
            } else if (sec.indexOf("WIFI\n") === 0) {
                body = sec.substring(5).trim()
                if (body) {
                    var lines = body.split("\n")
                    for (var i = 0; i < lines.length; i++) {
                        if (!lines[i]) continue
                        var parts = lines[i].split(":")
                        var ssid = parts[0]
                        if (!ssid || ssid === "--") continue
                        var isActive = parts[3] === "yes"
                        wifis.push({
                            ssid: ssid,
                            security: parts[1] || "Open",
                            signal: parseInt(parts[2]) || 0,
                            active: isActive
                        })
                    }
                    if (wifis.length > 1) {
                        var wifiMap = {}
                        for (var di = 0; di < wifis.length; di++) {
                            var w = wifis[di]
                            var existing = wifiMap[w.ssid]
                            if (!existing || w.active || (!existing.active && w.signal > existing.signal))
                                wifiMap[w.ssid] = w
                        }
                        wifis = []
                        for (var key in wifiMap) wifis.push(wifiMap[key])
                    }
                }
            } else if (sec.indexOf("RADIO\n") === 0) {
                wifiOn = sec.substring(6).trim() === "enabled"
            } else if (sec.indexOf("GENERAL\n") === 0) {
                body = sec.substring(8).trim()
                if (body) {
                    var parts = body.split(":")
                    if (parts.length > 0) connState = parts[0]
                    if (parts.length > 1) connLevel = parts[1]
                }
            } else if (sec.indexOf("CONNS\n") === 0) {
                body = sec.substring(6).trim()
                if (body) {
                    var conns = body.split("\n")
                    for (var ci = 0; ci < conns.length; ci++)
                        if (conns[ci]) savedCons.push(conns[ci])
                }
            } else if (sec.indexOf("ACTIVE\n") === 0) {
                body = sec.substring(7).trim()
                if (body) {
                    var conns = body.split("\n")
                    for (var ci = 0; ci < conns.length; ci++) {
                        for (var ni = 0; ni < wifis.length; ni++) {
                            if (conns[ci] && wifis[ni].ssid === conns[ci])
                                wifis[ni].active = true
                        }
                    }
                }
            }
        }
        return {
            wifiNetworks: wifis, ethernetDevices: eths,
            wifiEnabled: wifiOn, wifiDeviceName: devName,
            connectivityState: connState, connectivityLevel: connLevel,
            savedConnections: savedCons
        }
    }

    function hasSavedConnection(ssid) {
        for (var ci = 0; ci < savedConnections.length; ci++)
            if (savedConnections[ci] === ssid) return true
        return false
    }

    Process {
        id: fetchProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: rawText = text
        }
    }

    function runFetch(includeWifi) {
        if (fetchProc.running) return
        if (includeWifi === undefined) includeWifi = true
        if (includeWifi) {
            fetchProc.command = ["bash", "-c", "echo '###DEVICES'; nmcli -t device status 2>/dev/null; echo '###WIFI'; nmcli -t -f SSID,SECURITY,SIGNAL,ACTIVE device wifi list 2>/dev/null; echo '###RADIO'; nmcli radio wifi 2>/dev/null; echo '###GENERAL'; nmcli -t general status 2>/dev/null; echo '###CONNS'; nmcli -t -f NAME connection show 2>/dev/null; echo '###ACTIVE'; nmcli -t -f NAME connection show --active 2>/dev/null"]
        } else {
            fetchProc.command = ["bash", "-c", "echo '###DEVICES'; nmcli -t device status 2>/dev/null; echo '###RADIO'; nmcli radio wifi 2>/dev/null; echo '###GENERAL'; nmcli -t general status 2>/dev/null; echo '###CONNS'; nmcli -t -f NAME connection show 2>/dev/null; echo '###ACTIVE'; nmcli -t -f NAME connection show --active 2>/dev/null"]
        }
        fetchProc.running = true
    }

    Process {
        id: actionProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                runFetch(true)
                connectingSsid = ""
                disconnectingSsid = ""
                pendingEthDevice = ""
                ipcRefresh.running = true
            }
        }
    }

    Process {
        id: ipcRefresh
        command: ["qs", "ipc", "call", "refresh-network", "refresh"]
        running: false
    }

    function setWifiEnabled(val) {
        actionProc.command = ["nmcli", "radio", "wifi", val ? "on" : "off"]
        actionProc.running = true
        wifiEnabled = val
    }

    function connectToNetwork(ssid) {
        connectingSsid = ssid
        actionProc.command = hasSavedConnection(ssid)
            ? ["nmcli", "connection", "up", ssid]
            : ["nmcli", "device", "wifi", "connect", ssid]
        actionProc.running = true
    }

    function disconnectWifi() {
        if (!wifiDeviceName) return
        for (var i = 0; i < wifiNetworks.length; i++) {
            if (wifiNetworks[i].active) {
                disconnectingSsid = wifiNetworks[i].ssid
                break
            }
        }
        actionProc.command = ["nmcli", "device", "disconnect", wifiDeviceName]
        actionProc.running = true
    }

    function toggleEthernet(idx) {
        var list = ethernetDevices
        if (idx >= list.length) return
        var dev = list[idx]
        pendingEthDevice = dev.name
        actionProc.command = dev.state === "connected"
            ? ["nmcli", "device", "disconnect", dev.name]
            : ["nmcli", "device", "connect", dev.name]
        actionProc.running = true
    }

    function checkConnectivity() {
        actionProc.command = ["nmcli", "networking", "connectivity", "check"]
        actionProc.running = true
    }

    function launchNmtui() {
        actionProc.command = ["foot", "-e", "nmtui"]
        actionProc.running = true
    }

    function toggleWifiNetwork(idx) {
        var list = wifiNetworks
        if (idx >= list.length) return
        var net = list[idx]
        if (net.active) {
            disconnectWifi()
        } else if (net.security && net.security !== "Open" && !hasSavedConnection(net.ssid)) {
            launchNmtui()
        } else {
            connectToNetwork(net.ssid)
        }
    }

    // ---- Section 0: Wi-Fi list ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 0

        Text {
            width: parent.width
            height: 30
            visible: !root.wifiEnabled
            text: "Wi-Fi is turned off"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, 0.75)
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
        }

        Repeater {
            model: root.wifiNetworks
            visible: root.wifiEnabled

            delegate: Item {
                id: wifiItem
                width: parent.width
                height: 45
                property int wifiSignal: modelData.signal || 0

                Rectangle {
                    anchors.fill: parent
                    color: root.inSection && index === root.selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"
                }

                Text {
                    id: wifiLabel
                    text: modelData.ssid
                    anchors {
                        left: parent.left; leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    color: Colors.foreground
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideRight
                    width: parent.width * 0.45
                }

                Row {
                    anchors {
                        left: wifiLabel.right; leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    height: 10
                    spacing: 10

                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            width: 10
                            height: 10
                            color: index < Math.round(wifiItem.wifiSignal / 25)
                                   ? Colors.foreground : Qt.alpha(Colors.base0d, 0.75)
                        }
                    }
                }

                Text {
                    anchors {
                        right: parent.right; rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.connectingSsid === modelData.ssid
                        ? "Connecting..." : root.disconnectingSsid === modelData.ssid
                        ? "Disconnecting..." : modelData.active ? "Connected" : "Off"
                    color: modelData.active ? Colors.base0b : Qt.alpha(Colors.foreground, 0.75)
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
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
            height: 30
            visible: root.wifiEnabled && root.wifiNetworks.length === 0
            text: "No Wi-Fi networks found"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, 0.75)
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
        }
    }

    // ---- Section 1: Ethernet ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 1

        Repeater {
            model: root.ethernetDevices

            delegate: Item {
                width: parent.width
                height: 45

                Rectangle {
                    anchors.fill: parent
                    color: root.inSection && index === root.selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"
                }

                Text {
                    id: ethLabel
                    text: modelData.name || "(unnamed)"
                    anchors {
                        left: parent.left; leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    color: Colors.foreground
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideRight
                    width: parent.width * 0.45
                }

                Text {
                    text: modelData.connection || (modelData.state === "connected" ? "Connected" : "Disconnected")
                    anchors {
                        left: ethLabel.right; leftMargin: 10
                        right: ethStatus.left; rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    color: modelData.state === "connected" ? Colors.foreground : Qt.alpha(Colors.foreground, 0.75)
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideRight
                }

                Text {
                    id: ethStatus
                    anchors {
                        right: parent.right; rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.pendingEthDevice === modelData.name
                        ? (modelData.state === "connected" ? "Disconnecting..." : "Connecting...")
                        : modelData.state === "connected" ? "Connected" : "Off"
                    color: modelData.state === "connected" ? Colors.base0b : Colors.foreground
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    font.bold: modelData.state === "connected"
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
            height: 30
            visible: root.ethernetDevices.length === 0
            text: "No Ethernet devices"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, 0.75)
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
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
            leftPadding: 10
            color: Qt.alpha(Colors.foreground, 0.75)
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
            font.bold: true
        }

        Rectangle {
            width: parent.width
            height: 45
            color: root.inSection && 0 === root.selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"

            Text {
                text: "Wi-Fi: " + (root.wifiEnabled ? "On" : "Off")
                anchors {
                    left: parent.left; leftMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                color: Colors.foreground
                font.pixelSize: 16
                font.family: "JetBrainsMono Nerd Font"
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
            leftPadding: 10
            color: Qt.alpha(Colors.foreground, 0.75)
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
            font.bold: true
        }

        Rectangle {
            width: parent.width
            height: 45
            color: root.inSection && 2 === root.selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"

            Text {
                text: {
                    var connected = false
                    for (var ei = 0; ei < root.ethernetDevices.length; ei++) {
                        if (root.ethernetDevices[ei].state === "connected") { connected = true; break }
                    }
                    return "Ethernet: " + (connected ? "Connected" : "Disconnected")
                }
                anchors {
                    left: parent.left; leftMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                color: Colors.foreground
                font.pixelSize: 16
                font.family: "JetBrainsMono Nerd Font"
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
            height: 45
            color: root.inSection && 0 === root.selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"

            Text {
                text: "Connectivity: " + (root.connectivityLevel || root.connectivityState || "--")
                anchors {
                    left: parent.left; leftMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                color: Colors.foreground
                font.pixelSize: 16
                font.family: "JetBrainsMono Nerd Font"
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
            height: 45
            color: root.inSection && 1 === root.selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"

            Text {
                text: "nmtui"
                anchors {
                    left: parent.left; leftMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                color: Colors.foreground
                font.pixelSize: 16
                font.family: "JetBrainsMono Nerd Font"
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