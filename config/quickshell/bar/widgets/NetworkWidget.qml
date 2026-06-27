import "../../theme"
import QtQuick
import Quickshell.Io

Item {
    id: root
    width: contentRow.width + 20
    height: 30

    property string rawStatusText: ""

    property var parsedStatus: parseOutput(rawStatusText)

    property string statusText: parsedStatus.statusText
    property bool wifiIsEnabled: parsedStatus.wifiIsEnabled
    property int connectedSignal: parsedStatus.connectedSignal
    property bool wifiConnected: parsedStatus.wifiConnected
    property bool ethConnected: parsedStatus.ethConnected

    function parseOutput(text) {
        var devs = [], nets = [], wifiOn = false, sig = 0
        var wCon = false, eCon = false

        var sections = text.split("###")
        for (var si = 0; si < sections.length; si++) {
            var sec = sections[si]
            if (sec.indexOf("DEVICES\n") === 0) {
                var body = sec.substring(8).trim()
                if (!body) continue
                var lines = body.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":")
                    if (parts.length < 3) continue
                    devs.push({
                        name: parts[0],
                        type: parts[1],
                        state: parts[2].split(" ")[0],
                        connection: parts.slice(3).join(":")
                    })
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
                    nets.push({ ssid: ssid, active: active, signal: parseInt(parts[2]) || 0 })
                    if (active) sig = parseInt(parts[2]) || 0
                }
            } else if (sec.indexOf("RADIO\n") === 0) {
                wifiOn = sec.substring(6).trim() === "enabled"
            }
        }

        var status = "Net ----"
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i]
            if (d.state === "connected" && d.type === "wifi") { status = "WiFi On"; wCon = true; break }
            if (d.state === "connected" && d.type === "ethernet") { status = "Eth On"; eCon = true; break }
        }

        return {
            statusText: status, wifiIsEnabled: wifiOn,
            connectedSignal: sig, wifiConnected: wCon,
            ethConnected: eCon
        }
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
            onStreamFinished: rawStatusText = text
        }
    }

    Component.onCompleted: fetchStatus()

    Process {
        id: actionProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: fetchStatus()
        }
    }

    Process {
        id: ipcToggle
        command: ["qs", "ipc", "call", "overlay", "toggle", "network"]
        running: false
    }

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
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
                if (actionProc.running) return
                actionProc.command = ["nmcli", "radio", "wifi", wifiIsEnabled ? "off" : "on"]
                actionProc.running = true
            } else {
                ipcToggle.running = true
            }
        }
    }
}
