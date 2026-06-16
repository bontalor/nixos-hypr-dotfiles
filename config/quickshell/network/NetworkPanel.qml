import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: root
    title: "Network Control"
    color: "transparent"
    implicitWidth: 520
    implicitHeight: 520
    visible: false

    onClosed: visible = false

    property int selSection: 0
    property bool inSection: false
    property int selDevice: 0

    property var sections: [
        { name: "Wi-Fi" },
        { name: "Ethernet" },
        { name: "Configuration" },
        { name: "NetworkManager" }
    ]

    property var wifiNetworks: []
    property var ethernetDevices: []
    property bool wifiEnabled: false
    property string wifiDeviceName: ""
    property string connectivityState: ""
    property string connectivityLevel: ""
    property bool scanning: false
    property var savedConnections: []
    property string connectingSsid: ""
    property string disconnectingSsid: ""
    property string pendingEthDevice: ""

    function parseOutput(text, replaceNetworks) {
        var wifis = []
        var eths = []
        var wifiOn = false
        var devName = ""
        var connS = ""
        var connL = ""
        var activeConns = []
        var foundDevices = false
        var foundWifi = false
        var foundRadio = false
        var foundGeneral = false
        if (replaceNetworks === undefined) replaceNetworks = true

        var sections = text.split("###")
        for (var si = 0; si < sections.length; si++) {
            var sec = sections[si]
            if (sec.indexOf("DEVICES\n") === 0) {
                foundDevices = true
                var body = sec.substring(8).trim()
                if (!body) continue
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
            } else if (sec.indexOf("WIFI\n") === 0) {
                var body = sec.substring(5).trim()
                if (!body) continue
                foundWifi = true
                var lines = body.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue
                    var parts = lines[i].split(":")
                    var ssid = parts[0]
                    if (!ssid || ssid === "--") continue
                    var isActive = parts[3] === "yes"
                    if (replaceNetworks) {
                        wifis.push({
                            ssid: ssid,
                            security: parts[1] || "Open",
                            signal: parseInt(parts[2]) || 0,
                            active: isActive
                        })
                    } else {
                        for (var wi = 0; wi < wifiNetworks.length; wi++) {
                            if (wifiNetworks[wi].ssid === ssid) {
                                wifiNetworks[wi].active = isActive
                                break
                            }
                        }
                    }
                }

                if (replaceNetworks && wifis.length > 1) {
                    var wifiMap = {}
                    for (var di = 0; di < wifis.length; di++) {
                        var w = wifis[di]
                        var existing = wifiMap[w.ssid]
                        if (!existing || w.active || (!existing.active && w.signal > existing.signal)) {
                            wifiMap[w.ssid] = w
                        }
                    }
                    wifis = []
                    for (var key in wifiMap) wifis.push(wifiMap[key])
                }
            } else if (sec.indexOf("RADIO\n") === 0) {
                foundRadio = true
                wifiOn = sec.substring(6).trim() === "enabled"
            } else if (sec.indexOf("GENERAL\n") === 0) {
                foundGeneral = true
                var body = sec.substring(8).trim()
                if (body) {
                    var parts = body.split(":")
                    if (parts.length > 0) connS = parts[0]
                    if (parts.length > 1) connL = parts[1]
                }
            } else if (sec.indexOf("CONNS\n") === 0) {
                var body = sec.substring(6).trim()
                if (body) {
                    var conns = body.split("\n")
                    var list = []
                    for (var ci = 0; ci < conns.length; ci++) {
                        if (conns[ci]) list.push(conns[ci])
                    }
                    savedConnections = list
                }
            } else if (sec.indexOf("ACTIVE\n") === 0) {
                var body = sec.substring(7).trim()
                if (body) {
                    var conns = body.split("\n")
                    for (var ci = 0; ci < conns.length; ci++) {
                        if (conns[ci]) activeConns.push(conns[ci])
                    }
                }
            }
        }

        if (foundWifi && replaceNetworks) wifiNetworks = wifis
        if (foundDevices) { ethernetDevices = eths; wifiDeviceName = devName }
        if (foundRadio) wifiEnabled = wifiOn
        if (foundGeneral) { connectivityState = connS; connectivityLevel = connL }

        if (activeConns.length > 0) {
            for (var ni = 0; ni < wifiNetworks.length; ni++) {
                for (var aci = 0; aci < activeConns.length; aci++) {
                    if (wifiNetworks[ni].ssid === activeConns[aci]) {
                        wifiNetworks[ni].active = true
                        break
                    }
                }
            }
        }
    }

    function runFetch(includeWifi, replaceNetworks) {
        if (fetchProc.running) return
        if (includeWifi === undefined) includeWifi = true
        if (replaceNetworks === undefined) replaceNetworks = true
        if (includeWifi) {
            fetchProc.command = ["bash", "-c", "echo '###DEVICES'; nmcli -t device status 2>/dev/null; echo '###WIFI'; nmcli -t -f SSID,SECURITY,SIGNAL,ACTIVE device wifi list 2>/dev/null; echo '###RADIO'; nmcli radio wifi 2>/dev/null; echo '###GENERAL'; nmcli -t general status 2>/dev/null; echo '###CONNS'; nmcli -t -f NAME connection show 2>/dev/null; echo '###ACTIVE'; nmcli -t -f NAME connection show --active 2>/dev/null"]
        } else {
            fetchProc.command = ["bash", "-c", "echo '###DEVICES'; nmcli -t device status 2>/dev/null; echo '###RADIO'; nmcli radio wifi 2>/dev/null; echo '###GENERAL'; nmcli -t general status 2>/dev/null; echo '###CONNS'; nmcli -t -f NAME connection show 2>/dev/null; echo '###ACTIVE'; nmcli -t -f NAME connection show --active 2>/dev/null"]
        }
        fetchProc.replaceNetworks = replaceNetworks
        fetchProc.running = true
    }

    Process {
        id: fetchProc
        running: false
        property bool replaceNetworks: true
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: parseOutput(text, fetchProc.replaceNetworks)
        }
    }

    Process {
        id: actionProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                runFetch(true, true)
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

    Process {
        id: scanProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                scanDelay.running = true
            }
        }
    }

    Timer {
        id: scanDelay
        interval: 4000
        repeat: false
        property int retries: 0
        onTriggered: {
            scanning = false
            runFetch(true)
            retries = 0
        }
    }

    function scanWifi() {
        scanning = true
        scanProc.command = ["nmcli", "device", "wifi", "rescan"]
        scanProc.running = true
    }

    function setWifiEnabled(val) {
        actionProc.command = ["nmcli", "radio", "wifi", val ? "on" : "off"]
        actionProc.running = true
        wifiEnabled = val
    }

    function connectToNetwork(ssid) {
        connectingSsid = ssid
        if (hasSavedConnection(ssid)) {
            actionProc.command = ["nmcli", "connection", "up", ssid]
        } else {
            actionProc.command = ["nmcli", "device", "wifi", "connect", ssid]
        }
        actionProc.running = true
    }

    function disconnectWifi() {
        if (wifiDeviceName) {
            for (var i = 0; i < wifiNetworks.length; i++) {
                if (wifiNetworks[i].active) {
                    disconnectingSsid = wifiNetworks[i].ssid
                    break
                }
            }
            actionProc.command = ["nmcli", "device", "disconnect", wifiDeviceName]
            actionProc.running = true
        }
    }

    function toggleEthernet(idx) {
        var list = ethernetDevices
        if (idx >= list.length) return
        var dev = list[idx]
        pendingEthDevice = dev.name
        if (dev.state === "connected") {
            actionProc.command = ["nmcli", "device", "disconnect", dev.name]
            actionProc.running = true
        } else {
            actionProc.command = ["nmcli", "device", "connect", dev.name]
            actionProc.running = true
        }
    }

    function checkConnectivity() {
        actionProc.command = ["nmcli", "networking", "connectivity", "check"]
        actionProc.running = true
    }

    function launchNmtui() {
        actionProc.command = ["foot", "-e", "nmtui"]
        actionProc.running = true
    }

    function currentModelLength() {
        switch (selSection) {
        case 0: return wifiEnabled ? wifiNetworks.length + 1 : 0
        case 1: return ethernetDevices.length
        case 2: return 2
        case 3: return 2
        default: return 0
        }
    }

    function hasSavedConnection(ssid) {
        var list = savedConnections
        for (var ci = 0; ci < list.length; ci++) {
            if (list[ci] === ssid) return true
        }
        return false
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

    onSelDeviceChanged: if (flick && inSection && selSection < 2) flick.scrollToSelection()
    onInSectionChanged: if (flick && inSection) flick.scrollToSelection()

    onVisibleChanged: {
        if (visible) {
            runFetch(true, true)
            mainRect.forceActiveFocus()
            selSection = 0
            inSection = false
            selDevice = 0
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }

    Rectangle {
        id: mainRect
        anchors.fill: parent
        color: "transparent"
        focus: true

        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_Tab:
                if (event.modifiers & Qt.ShiftModifier) {
                    if (inSection) {
                        inSection = false
                    } else {
                        selSection = Math.max(selSection - 1, 0)
                    }
                } else if (inSection) {
                    var maxD = currentModelLength() - 1
                    selDevice = Math.min(selDevice + 1, Math.max(0, maxD))
                } else {
                    inSection = true
                    if (selSection < 2) selDevice = 0
                }
                event.accepted = true; break
            case Qt.Key_Backtab:
                if (inSection) {
                    inSection = false
                }
                event.accepted = true; break
            case Qt.Key_H:
            case Qt.Key_Left:
                event.accepted = true; break
            case Qt.Key_L:
            case Qt.Key_Right:
                event.accepted = true; break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (selSection === 0 && inSection) {
                    if (selDevice === 0) {
                        if (!scanning) scanWifi()
                    } else {
                        toggleWifiNetwork(selDevice - 1)
                    }
                } else if (selSection === 1 && inSection) {
                    toggleEthernet(selDevice)
                } else if (selSection === 2 && inSection) {
                    if (selDevice === 0) {
                        setWifiEnabled(!wifiEnabled)
                    }
                } else if (selSection === 3 && inSection) {
                    if (selDevice === 0) {
                        checkConnectivity()
                    } else if (selDevice === 1) {
                        launchNmtui()
                    }
                } else if (!inSection) {
                    inSection = true
                    if (selSection < 2) selDevice = 0
                }
                event.accepted = true; break
            case Qt.Key_J:
            case Qt.Key_Down:
                if (inSection) {
                    var maxD = currentModelLength() - 1
                    selDevice = Math.min(selDevice + 1, Math.max(0, maxD))
                } else {
                    selSection = Math.min(selSection + 1, sections.length - 1)
                }
                event.accepted = true; break
            case Qt.Key_K:
            case Qt.Key_Up:
                if (inSection) {
                    selDevice = Math.max(selDevice - 1, 0)
                } else {
                    selSection = Math.max(selSection - 1, 0)
                }
                event.accepted = true; break
            case Qt.Key_Escape:
                event.accepted = true; break
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                width: (parent.width - parent.spacing) * 0.25
                height: parent.height
                color: Qt.alpha(Colors.base00, 0.75)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Repeater {
                        model: sections

                        delegate: Rectangle {
                            width: parent.width
                            height: 30
                            color: selSection === index ? Qt.alpha(Colors.base01, 0.75) : "transparent"

                            Text {
                                id: nameText
                                text: modelData.name
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    right: parent.right; rightMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                elide: Text.ElideRight
                                leftPadding: selSection === index && inSection ? 18 : 0
                            }

                            Text {
                                text: "\u25b6"
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                visible: selSection === index && inSection
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    selSection = index
                                    inSection = false
                                    mainRect.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: (parent.width - parent.spacing) * 0.75
                height: parent.height
                color: Qt.alpha(Colors.base00, 0.75)

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 10
                    contentHeight: contentCol.height
                    clip: true

                    function scrollToVisible(itemY, itemH) {
                        var viewH = flick.height
                        var maxY = Math.max(0, contentCol.height - viewH)
                        if (itemY < flick.contentY) {
                            flick.contentY = Math.max(0, itemY - 40)
                        } else if (itemY + itemH > flick.contentY + viewH) {
                            flick.contentY = Math.min(maxY, itemY + itemH - viewH + 10)
                        }
                    }

                    function scrollToSelection() {
                        var y, h
                        if (inSection) {
                            if (selSection === 0 && wifiEnabled) {
                                y = selDevice === 0 ? 40 : 40 + 55 * selDevice
                            } else {
                                y = 40 + selDevice * 55
                            }
                            h = 45
                        }
                        if (y !== undefined) flick.scrollToVisible(y, h)
                    }

                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            width: parent.width
                            height: 30
                            color: Qt.alpha(Colors.base0d, 0.75)

                            Text {
                                text: sections[selSection]?.name ?? ""
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                font.bold: true
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: selSection === 0

                            Text {
                                width: parent.width
                                height: 30
                                visible: !wifiEnabled
                                text: "Wi-Fi is turned off"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: Qt.alpha(Colors.foreground, 0.75)
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                            }

                            Rectangle {
                                width: parent.width
                                height: 45
                                visible: wifiEnabled
                                color: inSection && selDevice === 0 ? Qt.alpha(Colors.base01, 0.75) : "transparent"

                                Text {
                                    text: scanning ? "Scanning..." : "Scan"
                                    anchors {
                                        left: parent.left; leftMargin: 10
                                        verticalCenter: parent.verticalCenter
                                    }
                                    color: scanning ? Qt.alpha(Colors.foreground, 0.75) : Colors.foreground
                                    font.pixelSize: 16
                                    font.family: "JetBrainsMono Nerd Font"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!inSection) { inSection = true; selDevice = 0 }
                                        if (!scanning) scanWifi()
                                    }
                                }
                            }

                            Repeater {
                                model: wifiNetworks
                                visible: wifiEnabled

                                delegate: Item {
                                    id: wifiItem
                                    width: parent.width
                                    height: 45
                                    property int wifiSignal: modelData.signal || 0

                                    Rectangle {
                                        anchors.fill: parent
                                        color: inSection && index + 1 === selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"
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
                                        id: signalRow
                                        anchors {
                                            left: wifiLabel.right; leftMargin: 10
                                            verticalCenter: parent.verticalCenter
                                        }
                                        height: 10
                                        spacing: 10

                                        Repeater {
                                            id: signalRepeater
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
                                        id: wifiStatus
                                        anchors {
                                            right: parent.right; rightMargin: 10
                                            verticalCenter: parent.verticalCenter
                                        }
                                        text: connectingSsid === modelData.ssid
                                            ? "Connecting..." : disconnectingSsid === modelData.ssid
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
                                            if (!inSection) { inSection = true; selDevice = index + 1 }
                                            toggleWifiNetwork(index)
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                height: 30
                                visible: wifiEnabled && wifiNetworks.length === 0
                                text: scanning ? "Scanning..." : "No Wi-Fi networks found"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: Qt.alpha(Colors.foreground, 0.75)
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: selSection === 1

                            Repeater {
                                model: ethernetDevices

                                delegate: Item {
                                    id: ethItem
                                    width: parent.width
                                    height: 45

                                    Rectangle {
                                        anchors.fill: parent
                                        color: inSection && index === selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"
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
                                        id: ethAddr
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
                                        text: pendingEthDevice === modelData.name
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
                                            if (!inSection) { inSection = true; selDevice = index }
                                            toggleEthernet(index)
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                height: 30
                                visible: ethernetDevices.length === 0
                                text: "No Ethernet devices"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: Qt.alpha(Colors.foreground, 0.75)
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: selSection === 2

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
                                color: inSection && 0 === selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"

                                Text {
                                    text: "Wi-Fi: " + (wifiEnabled ? "On" : "Off")
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
                                        if (!inSection) { inSection = true; selDevice = 0 }
                                        setWifiEnabled(!wifiEnabled)
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
                                color: inSection && 2 === selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"

                                Text {
                                    text: {
                                        var connected = false
                                        for (var ei = 0; ei < ethernetDevices.length; ei++) {
                                            if (ethernetDevices[ei].state === "connected") { connected = true; break }
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

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: selSection === 3

                            Rectangle {
                                width: parent.width
                                height: 45
                                color: inSection && 0 === selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"

                                Text {
                                    text: "Connectivity: " + (connectivityLevel || connectivityState || "--")
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
                                        if (!inSection) { inSection = true; selDevice = 0 }
                                        checkConnectivity()
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 45
                                color: inSection && 1 === selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"

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
                                        if (!inSection) { inSection = true; selDevice = 1 }
                                        launchNmtui()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
