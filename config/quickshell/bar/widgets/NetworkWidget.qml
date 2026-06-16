import "../../theme"
import QtQuick
import Quickshell.Io

Item {
    id: root
    width: contentRow.width + 20
    height: 30

    property string statusText: "Net ----"
    property bool wifiIsEnabled: false
    property int connectedSignal: 0
    property bool wifiConnected: false
    property bool ethConnected: false

    function parseOutput(text) {
        var sections = text.split("###")
        var devs = []
        var nets = []
        var wifiOn = false
        var sig = 0
        var wCon = false
        var eCon = false

        for (var si = 0; si < sections.length; si++) {
            var sec = sections[si]
            if (sec.indexOf("DEVICES\n") === 0) {
                var body = sec.substring(8).trim()
                if (!body) continue
                var lines = body.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":")
                    var t = parts[1]
                    if (t === "wifi" || t === "ethernet") {
                        devs.push({
                            name: parts[0],
                            type: t,
                            state: parts[2].split(" ")[0],
                            connection: parts.slice(3).join(":")
                        })
                    }
                }
            } else if (sec.indexOf("WIFI\n") === 0) {
                var body = sec.substring(5).trim()
                if (!body) continue
                var lines = body.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue
                    var parts = lines[i].split(":")
                    var ssid = parts[0]
                    if (!ssid || ssid === "--") continue
                    var active = parts[3] === "yes"
                    nets.push({
                        ssid: ssid,
                        active: active,
                        signal: parseInt(parts[2]) || 0
                    })
                    if (active) sig = parseInt(parts[2]) || 0
                }
            } else if (sec.indexOf("RADIO\n") === 0) {
                wifiOn = sec.substring(6).trim() === "enabled"
            }
        }

        wifiIsEnabled = wifiOn

        for (var i = 0; i < devs.length; i++) {
            var d = devs[i]
            if (d.state === "connected" && d.type === "wifi") {
                statusText = "WiFi On"
                wCon = true
                break
            }
            if (d.state === "connected" && d.type === "ethernet") {
                statusText = "Eth On"
                eCon = true
                break
            }
        }

        if (!wCon && !eCon) statusText = "Net ----"
        connectedSignal = sig
        wifiConnected = wCon
        ethConnected = eCon
    }

    function fetchStatus() {
        fetchProc.command = ["bash", "-c", "echo '###DEVICES'; nmcli -t device status 2>/dev/null; echo '###WIFI'; nmcli -t -f SSID,SECURITY,SIGNAL,ACTIVE device wifi list 2>/dev/null; echo '###RADIO'; nmcli radio wifi 2>/dev/null"]
        fetchProc.running = true
    }

    Process {
        id: fetchProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: parseOutput(text)
        }
    }

    // Fallback: refresh network status every 30s
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: fetchStatus()
    }

    Component.onCompleted: fetchStatus()

    Process {
        id: actionProc
        running: false
    }

    Process {
        id: ipcToggle
        command: ["qs", "ipc", "call", "overlay", "toggle", "network"]
        running: false
    }

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? Qt.alpha(Colors.base08, 0.75) : "transparent"
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: netText
            text: root.statusText
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
            color: Colors.foreground
        }

        Row {
            visible: wifiConnected
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: 4
                delegate: Rectangle {
                    width: 10
                    height: 10
                    color: index < Math.round(connectedSignal / 25)
                           ? Colors.foreground : Qt.alpha(Colors.base0d, 0.75)
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                actionProc.command = ["nmcli", "radio", "wifi", wifiIsEnabled ? "off" : "on"]
                actionProc.running = true
                fetchStatus()
            } else {
                ipcToggle.running = true
            }
        }
    }
}
