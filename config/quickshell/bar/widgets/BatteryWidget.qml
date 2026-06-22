import "../../theme"
import QtQuick
import Quickshell.Io

Item {
    id: root
    width: batText.width + 20
    height: 30

    property string statusText: "Bat ----"
    property int batteryPercent: -1
    property string batteryState: ""
    property string activeProfile: ""

    function parseOutput(text) {
        var pct = -1
        var state = ""
        var profile = ""
        var lines = text.split("\n")
        var inProfile = false
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "###PROFILE") {
                inProfile = true
                continue
            }
            if (inProfile) {
                if (line.length > 0 && line.indexOf("###") !== 0) {
                    profile = line
                }
                continue
            }
            if (line.indexOf("percentage:") === 0) {
                var val = line.substring(line.indexOf(":") + 1).trim()
                pct = parseInt(val) || -1
            } else if (line.indexOf("state:") === 0) {
                state = line.substring(line.indexOf(":") + 1).trim()
            }
        }

        batteryPercent = pct
        batteryState = state
        activeProfile = profile

        var profileSymbol = ""
        if (profile === "performance") profileSymbol = "\uf0e7"
        else if (profile === "balanced") profileSymbol = "\uf0eb"
        else if (profile === "power-saver") profileSymbol = "\uf06c"

        var plugged = state === "charging" || state === "pending-charge" || state === "fully-charged"
        var plugSymbol = plugged ? "\uf1e6 " : ""

        if (pct < 0 || !state) {
            statusText = "Bat ----"
        } else if (state === "charging" || state === "pending-charge") {
            statusText = "Bat " + ("  " + pct).slice(-3) + "%+ " + plugSymbol + profileSymbol
        } else if (state === "fully-charged") {
            statusText = "Bat " + ("  " + pct).slice(-3) + "% " + plugSymbol + profileSymbol
        } else {
            statusText = "Bat " + ("  " + pct).slice(-3) + "% " + plugSymbol + profileSymbol
        }
    }

    function fetchStatus() {
        fetchProc.command = ["bash", "-c", "upower -i $(upower -e 2>/dev/null | grep battery | grep -v DisplayDevice | head -1) 2>/dev/null; echo '###PROFILE'; powerprofilesctl get 2>/dev/null || cat /sys/firmware/acpi/platform_profile 2>/dev/null"]
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

    // Fallback: refresh battery status every 60s
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: fetchStatus()
    }

    Component.onCompleted: fetchStatus()

    Process {
        id: ipcToggle
        command: ["qs", "ipc", "call", "overlay", "toggle", "battery"]
        running: false
    }

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
    }

    Text {
        id: batText
        anchors.centerIn: parent
        text: root.statusText
        font.pixelSize: 16
        font.family: "JetBrainsMono Nerd Font"
        color: {
            if (batteryPercent < 0) return Colors.foreground
            if (batteryPercent <= 15) return Colors.base08
            if (batteryPercent <= 25) return Colors.base09
            return Colors.foreground
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
                // no right-click action yet
            } else {
                ipcToggle.running = true
            }
        }
    }
}
