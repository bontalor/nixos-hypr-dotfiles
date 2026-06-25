import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: root
    title: "Battery & Power"
    color: "transparent"
    implicitWidth: 850
    implicitHeight: 450
    visible: false

    onClosed: visible = false

    property int selSection: 0
    property bool inSection: false
    property int selDevice: 0

    property var sections: [
        { name: "Battery" },
        { name: "Power Profiles" }
    ]

    property int batteryPercent: -1
    property string batteryState: ""
    property string batteryTime: ""
    property int batteryTimeNum: -1
    property string batteryModel: ""

    property var powerProfiles: []
    property string activeProfile: ""
    property bool profileDaemonAvailable: true

    function parseOutput(text) {
        var pct = -1
        var state = ""
        var timeText = ""
        var model = ""
        var proflist = []
        var active = ""
        var daemonOk = true

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
                        var val = line.substring(line.indexOf(":") + 1).trim()
                        pct = parseInt(val) || -1
                    } else if (line.indexOf("state:") === 0) {
                        state = line.substring(line.indexOf(":") + 1).trim()
                    } else if (line.indexOf("time to empty:") === 0) {
                        timeText = line.substring(line.indexOf(":") + 1).trim()
                    } else if (line.indexOf("time to full:") === 0) {
                        timeText = line.substring(line.indexOf(":") + 1).trim()
                    } else if (line.indexOf("model:") === 0) {
                        model = line.substring(line.indexOf(":") + 1).trim()
                    }
                }
            } else if (sec.indexOf("PROFILES\n") === 0) {
                var body = sec.substring(9).trim()
                if (!body) { daemonOk = false; continue }
                var lines = body.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (line.indexOf("NOT AVAILABLE") >= 0) {
                        daemonOk = false
                        break
                    }
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

        batteryPercent = pct
        batteryState = state
        batteryTime = timeText
        batteryModel = model
        powerProfiles = proflist
        activeProfile = active
        profileDaemonAvailable = daemonOk
    }

    function runFetch() {
        if (fetchProc.running) {
            pendingFetch = true
            return
        }
        fetchProc.command = ["bash", "-c", "echo '###BATTERY'; upower -i $(upower -e 2>/dev/null | grep battery | grep -v DisplayDevice | head -1) 2>/dev/null; echo '###PROFILES'; if powerprofilesctl list 2>/dev/null; then :; elif [ -r /sys/firmware/acpi/platform_profile ]; then ACTIVE=$(cat /sys/firmware/acpi/platform_profile); for p in $(cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null); do if [ \"$p\" = \"$ACTIVE\" ]; then echo \"* $p:\"; else echo \"  $p:\"; fi; done; else echo 'NOT AVAILABLE'; fi"]
        fetchProc.running = true
    }

    property bool pendingFetch: false

    Process {
        id: fetchProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                parseOutput(text)
                if (pendingFetch) {
                    pendingFetch = false
                    fetchProc.running = true
                }
            }
        }
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
        for (var i = 0; i < powerProfiles.length; i++) {
            powerProfiles[i].active = powerProfiles[i].name === name
        }
        powerProfiles = powerProfiles.slice()
        activeProfile = name
        actionProc.command = ["bash", "-c", "powerprofilesctl set '" + cmdName + "' 2>&1"]
        actionProc.running = true
    }

    function currentModelLength() {
        switch (selSection) {
        case 0: return batteryPercent >= 0 ? 1 : 0
        case 1: return powerProfiles.length
        default: return 0
        }
    }

    onSelDeviceChanged: if (flick && inSection && selSection < 2) flick.scrollToSelection()
    onInSectionChanged: if (flick && inSection) flick.scrollToSelection()

    onVisibleChanged: {
        if (visible) {
            runFetch()
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
                    selDevice = 0
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
                if (selSection === 1 && inSection && selDevice < powerProfiles.length) {
                    setProfile(powerProfiles[selDevice].name)
                } else if (!inSection) {
                    inSection = true
                    selDevice = 0
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
                            y = 40 + selDevice * 55
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

                            Rectangle {
                                width: parent.width
                                height: 45 + (batteryPercent >= 0 ? 30 * 2 : 0)
                                color: inSection && 0 === selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"

                                Column {
                                    anchors {
                                        left: parent.left; leftMargin: 10
                                        verticalCenter: parent.verticalCenter
                                    }
                                    spacing: 2

                                    Text {
                                        text: batteryModel || "Battery"
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.bold: true
                                        visible: batteryPercent >= 0
                                    }

                                    Text {
                                        visible: batteryPercent >= 0
                                        text: {
                                            var plugged = batteryState === "charging" || batteryState === "pending-charge" || batteryState === "fully-charged"
                                            var prefix = plugged ? "\uf1e6 " : ""
                                            var s = batteryState
                                                ? batteryState.charAt(0).toUpperCase() + batteryState.slice(1)
                                                : ""
                                            if (batteryTime) s += " (" + batteryTime + ")"
                                            return prefix + s
                                        }
                                        color: batteryState === "charging"
                                            ? Colors.base0b
                                            : (batteryPercent <= 15 ? Colors.base08 : Qt.alpha(Colors.foreground, 0.75))
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: batteryPercent >= 0
                                        text: batteryPercent + "%"
                                        color: {
                                            if (batteryPercent <= 15) return Colors.base08
                                            if (batteryPercent <= 25) return Colors.base09
                                            return Colors.foreground
                                        }
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.bold: true
                                    }

                                    Text {
                                        visible: batteryPercent < 0
                                        text: "No battery detected"
                                        color: Qt.alpha(Colors.foreground, 0.75)
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: selSection === 1

                            Text {
                                width: parent.width
                                height: 30
                                visible: !profileDaemonAvailable
                                text: "power-profiles-daemon not available"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: Qt.alpha(Colors.foreground, 0.75)
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                            }

                            Repeater {
                                model: powerProfiles

                                delegate: Item {
                                    width: parent.width
                                    height: 45

                                    Rectangle {
                                        anchors.fill: parent
                                        color: inSection && index === selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"
                                    }

                                    Row {
                                        anchors {
                                            left: parent.left; leftMargin: 10
                                            verticalCenter: parent.verticalCenter
                                        }
                                        spacing: 8

                                Text {
                                    id: profileIcon
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
                                            if (!inSection) { inSection = true; selDevice = index }
                                            if (!modelData.active) setProfile(modelData.name)
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
}
