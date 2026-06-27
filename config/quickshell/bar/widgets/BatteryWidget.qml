import "../../theme"
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    width: batText.width + 20
    height: 30

    property string rawBatteryText: ""
    property string rawProfileText: ""

    property var parsedBattery: parseBatteryOutput(rawBatteryText)
    property int batteryPercent: parsedBattery.batteryPercent
    property bool isCharging: parsedBattery.isCharging
    property string activeProfile: rawProfileText.trim()

    property string statusText: computeStatusText(batteryPercent, isCharging, activeProfile)

    function parseBatteryOutput(text) {
        var pct = -1
        var charging = false
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.indexOf("percentage:") === 0) {
                var val = parseInt(line.substring(line.indexOf(":") + 1).trim())
                pct = isNaN(val) ? -1 : val
            } else if (line.indexOf("state:") === 0) {
                var st = line.substring(line.indexOf(":") + 1).trim()
                charging = st === "charging"
            }
        }
        return { batteryPercent: pct, isCharging: charging }
    }

    function computeStatusText(pct, charging, profile) {
        if (pct < 0) return "Bat ----"

        var profileSymbol = ""
        var p = profile.toLowerCase()
        if (p === "performance") profileSymbol = "\uf0e7"
        else if (p === "balanced") profileSymbol = "\uf0eb"
        else if (p === "power-saver" || p === "power-save" || p === "powersave") profileSymbol = "\uf06c"

        var plugSymbol = charging ? "\uf1e6 " : ""

        if (charging)
            return "Bat " + ("  " + pct).slice(-3) + "%+ " + profileSymbol + plugSymbol
        else
            return "Bat " + ("  " + pct).slice(-3) + "% " + profileSymbol + plugSymbol
    }

    function refreshBattery() {
        if (batProc.running) return
        batProc.command = ["bash", "-c", "upower -i $(upower -e 2>/dev/null | grep battery | grep -v DisplayDevice | head -1) 2>/dev/null"]
        batProc.running = true
    }

    function fetchStatus() {
        if (profileProc.running) return
        profileProc.command = ["bash", "-c",
            "[ -r /sys/firmware/acpi/platform_profile ] && cat /sys/firmware/acpi/platform_profile 2>/dev/null || powerprofilesctl get 2>/dev/null || echo ''"]
        profileProc.running = true
    }

    Timer {
        id: batteryTimer
        interval: 5000
        repeat: true
        running: true
        onTriggered: refreshBattery()
    }

    Timer {
        id: profileTimer
        interval: 5000
        repeat: true
        running: true
        onTriggered: fetchStatus()
    }

    Process {
        id: batProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: rawBatteryText = text
        }
    }

    Process {
        id: profileProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: rawProfileText = text
        }
    }

    Component.onCompleted: { refreshBattery(); fetchStatus() }

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
        onClicked: ipcToggle.running = true
    }
}
