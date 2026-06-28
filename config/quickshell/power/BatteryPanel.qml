import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io

Panel {
    id: root
    title: "Battery & Power"
    sections: [
        { name: "Battery" },
        { name: "Power Profiles" }
    ]

    property string rawText: ""
    property var parsedData: parseAll(rawText)

    property int batteryPercent: parsedData.batteryPercent
    property string batteryState: parsedData.batteryState
    property string batteryTime: parsedData.batteryTime
    property string batteryModel: parsedData.batteryModel

    property var powerProfiles: parsedData.powerProfiles
    property string activeProfile: parsedData.activeProfile
    property bool profileDaemonAvailable: parsedData.profileDaemonAvailable

    currentModelLength: function() {
        switch (root.selSection) {
        case 0: return root.batteryPercent >= 0 ? 1 : 0
        case 1: return root.powerProfiles.length
        default: return 0
        }
    }

    onShown: runFetch()
    onDeviceActivated: function(idx) {
        if (root.selSection === 1 && idx < root.powerProfiles.length)
            setProfile(root.powerProfiles[idx].name)
    }

    function parseAll(text) {
        var pct = -1, state = "", timeText = "", model = ""
        var proflist = [], active = "", daemonOk = true

        var sections = text.split("###")
        for (var si = 0; si < sections.length; si++) {
            var sec = sections[si]
            if (sec.indexOf("BATTERY\n") === 0) {
                var body = sec.substring(8).trim()
                if (!body) continue
                var lines = body.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.indexOf("percentage:") === 0) {
                        pct = parseInt(line.substring(line.indexOf(":") + 1).trim()) || -1
                    } else if (line.indexOf("state:") === 0) {
                        state = line.substring(line.indexOf(":") + 1).trim()
                    } else if (line.indexOf("time to empty:") === 0 || line.indexOf("time to full:") === 0) {
                        timeText = line.substring(line.indexOf(":") + 1).trim()
                    } else if (line.indexOf("model:") === 0) {
                        model = line.substring(line.indexOf(":") + 1).trim()
                    }
                }
            } else if (sec.indexOf("PROFILES\n") === 0) {
                body = sec.substring(9).trim()
                if (!body) { daemonOk = false; continue }
                var lines = body.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (line.indexOf("NOT AVAILABLE") >= 0) { daemonOk = false; break }
                    var trimmed = line.trim()
                    if (trimmed.length === 0) continue
                    var spaceCount = 0
                    while (spaceCount < line.length && line.charAt(spaceCount) === " ") spaceCount++
                    if (trimmed.charAt(trimmed.length - 1) === ":" && (spaceCount === 0 || spaceCount === 2)) {
                        var rawName = trimmed.substring(0, trimmed.length - 1)
                        if (rawName.charAt(0) === "*") rawName = rawName.substring(2)
                        var parts = rawName.split("-")
                        var normalized = ""
                        for (var pi = 0; pi < parts.length; pi++) {
                            if (pi > 0) normalized += " "
                            var p = parts[pi]
                            if (p.length > 0) normalized += p.charAt(0).toUpperCase() + p.substring(1)
                        }
                        var isActive = line.charAt(0) === "*"
                        proflist.push({ name: normalized, active: isActive })
                        if (isActive) active = normalized
                    }
                }
                if (proflist.length > 0) daemonOk = true
            }
        }

        return {
            batteryPercent: pct, batteryState: state,
            batteryTime: timeText, batteryModel: model,
            powerProfiles: proflist, activeProfile: active,
            profileDaemonAvailable: daemonOk
        }
    }

    property bool pendingFetch: false

    Process {
        id: fetchProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                rawText = text
                if (pendingFetch) {
                    pendingFetch = false
                    fetchProc.running = true
                }
            }
        }
    }

    function runFetch() {
        if (fetchProc.running) { pendingFetch = true; return }
        fetchProc.command = ["bash", "-c", "echo '###BATTERY'; upower -i $(upower -e 2>/dev/null | grep battery | grep -v DisplayDevice | head -1) 2>/dev/null; echo '###PROFILES'; if powerprofilesctl list 2>/dev/null; then :; elif [ -r /sys/firmware/acpi/platform_profile ]; then ACTIVE=$(cat /sys/firmware/acpi/platform_profile); for p in $(cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null); do if [ \"$p\" = \"$ACTIVE\" ]; then echo \"* $p:\"; else echo \"  $p:\"; fi; done; else echo 'NOT AVAILABLE'; fi"]
        fetchProc.running = true
    }

    Process {
        id: actionProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                runFetch()
                ipcRefresh.running = true
            }
        }
    }

    Process {
        id: ipcRefresh
        command: ["qs", "ipc", "call", "refresh-battery", "refresh"]
        running: false
    }

    function setProfile(name) {
        var cmdName = name.toLowerCase().replace(/ /g, '-')
        for (var i = 0; i < powerProfiles.length; i++)
            powerProfiles[i].active = powerProfiles[i].name === name
        powerProfiles = powerProfiles.slice()
        activeProfile = name
        actionProc.command = ["powerprofilesctl", "set", cmdName]
        actionProc.running = true
    }

    // ---- Section 0: Battery summary ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 0

        Rectangle {
            width: parent.width
            height: 45 + (root.batteryPercent >= 0 ? 30 * 2 : 0)
            color: root.inSection && 0 === root.selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"

            Column {
                anchors {
                    left: parent.left; leftMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                spacing: 2

                Text {
                    text: root.batteryModel || "Battery"
                    color: Colors.foreground
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    font.bold: true
                    visible: root.batteryPercent >= 0
                }

                Text {
                    visible: root.batteryPercent >= 0
                    text: {
                        var plugged = root.batteryState === "charging" || root.batteryState === "pending-charge" || root.batteryState === "fully-charged"
                        var prefix = plugged ? "\uf1e6 " : ""
                        var s = root.batteryState
                            ? root.batteryState.charAt(0).toUpperCase() + root.batteryState.slice(1)
                            : ""
                        if (root.batteryTime) s += " (" + root.batteryTime + ")"
                        return prefix + s
                    }
                    color: root.batteryState === "charging"
                        ? Colors.base0b
                        : (root.batteryPercent <= 15 ? Colors.base08 : Qt.alpha(Colors.foreground, 0.75))
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                }

                Text {
                    visible: root.batteryPercent >= 0
                    text: root.batteryPercent + "%"
                    color: {
                        if (root.batteryPercent <= 15) return Colors.base08
                        if (root.batteryPercent <= 25) return Colors.base09
                        return Colors.foreground
                    }
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    font.bold: true
                }

                Text {
                    visible: root.batteryPercent < 0
                    text: "No battery detected"
                    color: Qt.alpha(Colors.foreground, 0.75)
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                }
            }
        }
    }

    // ---- Section 1: Power Profiles ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 1

        Text {
            width: parent.width
            height: 30
            visible: !root.profileDaemonAvailable
            text: "power-profiles-daemon not available"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, 0.75)
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
        }

        Repeater {
            model: root.powerProfiles

            delegate: Item {
                width: parent.width
                height: 45

                Rectangle {
                    anchors.fill: parent
                    color: root.inSection && index === root.selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"
                }

                Row {
                    anchors {
                        left: parent.left; leftMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 8

                    Text {
                        text: {
                            if (modelData.name === "Performance") return "\uf0e7"
                            if (modelData.name === "Balanced") return "\uf0eb"
                            if (modelData.name === "Power Saver") return "\uf06c"
                            return "\uf128"
                        }
                        color: modelData.active ? Colors.base0b : Qt.alpha(Colors.foreground, 0.75)
                        font.pixelSize: 16
                        font.family: "JetBrainsMono Nerd Font"
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        text: modelData.name
                        color: modelData.active ? Colors.base0b : Colors.foreground
                        font.pixelSize: 16
                        font.family: "JetBrainsMono Nerd Font"
                        font.bold: modelData.active
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    text: modelData.active ? "Active" : ""
                    anchors {
                        right: parent.right; rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    color: Colors.base0b
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.inSection) { root.inSection = true; root.selDevice = index }
                        if (!modelData.active) root.setProfile(modelData.name)
                    }
                }
            }
        }
    }
}