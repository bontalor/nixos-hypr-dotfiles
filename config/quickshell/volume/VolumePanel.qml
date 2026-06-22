import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Widgets

FloatingWindow {
    id: root
    title: "Volume Control"
    color: "transparent"
    implicitWidth: 850
    implicitHeight: 450
    visible: false

    onClosed: visible = false

    PwObjectTracker {
        id: nodeTracker
        objects: []
    }

    property int selSection: 0
    property bool inSection: false
    property int selDevice: 0

    property var sections: [
        { name: "Playback" },
        { name: "Recording" },
        { name: "Output Devices" },
        { name: "Input Devices" },
        { name: "Configuration" }
    ]

    property var playbackStreams: []
    property var recordingStreams: []
    property var sinkNodes: []
    property var sourceNodes: []

    property var configDevices: []
    property int selConfigDevice: 0
    property bool configExpanded: false
    property int selConfigProfile: 0

    property int peakFps: 20
    property real peakDecay: 0.05

    function isMonitorNode(n) {
        if (n.name) {
            if (n.name === "quickshell") return true
            if (n.name.indexOf("quickshell-peak-monitor") >= 0) return true
        }
        if (n.properties) {
            if (n.properties["media.category"] === "Monitor") return true
            if (n.properties["stream.monitor"] === "true") return true
            if (n.properties["application.name"] === "Quickshell Peak Detect") return true
        }
        return false
    }

    function refreshNodeLists() {
        var pbs = [], rcs = [], sks = [], srcs = []
        var raw = Pipewire.nodes
        var vals = raw && raw.values ? raw.values : []
        nodeTracker.objects = vals

        for (var i = 0; i < vals.length; i++) {
            var n = vals[i]
            if (!n.audio || isMonitorNode(n)) continue
            if (n.isStream) {
                if (n.type === PwNodeType.AudioOutStream) pbs.push(n)
                else if (n.type === PwNodeType.AudioInStream) rcs.push(n)
            }
            if (n.isSink && !n.isStream) sks.push(n)
            else if (!n.isSink && !n.isStream && n.type === PwNodeType.AudioSource) srcs.push(n)
        }
        playbackStreams = pbs
        recordingStreams = rcs
        sinkNodes = sks
        sourceNodes = srcs
    }

    Timer {
        id: refreshDebounce
        interval: 100
        repeat: false
        onTriggered: { if (root.visible) refreshNodeLists() }
    }

    function currentModel() {
        switch (selSection) {
        case 0: return playbackStreams
        case 1: return recordingStreams
        case 2: return sinkNodes
        case 3: return sourceNodes
        default: return []
        }
    }

    function changeVolume(delta) {
        var list = currentModel()
        if (selDevice >= list.length) return
        var node = list[selDevice]
        if (node && node.audio) {
            node.audio.volume = Math.max(0, Math.min(1, node.audio.volume + delta))
        }
    }

    function changeDeviceVolume(idx, fraction) {
        var list = currentModel()
        if (idx >= list.length) return
        var node = list[idx]
        if (node && node.audio) {
            node.audio.volume = Math.max(0, Math.min(1, fraction))
        }
    }

    function toggleDeviceMute(idx) {
        var list = currentModel()
        if (idx >= list.length) return
        var node = list[idx]
        if (node && node.audio) {
            node.audio.muted = !node.audio.muted
        }
    }

    function parseConfigDevices(text) {
        var devices = []
        var current = null
        var lines = text.trim().split('\n')
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.startsWith('DEVICE:')) {
                var parts = line.substring(7).split('|')
                current = { id: parseInt(parts[0]), description: parts[1], currentProfile: parseInt(parts[2]), profiles: [] }
                devices.push(current)
            } else if (line.startsWith('PROFILE:') && current) {
                var parts = line.substring(8).split('|')
                current.profiles.push({
                    index: parseInt(parts[0]),
                    name: parts[1],
                    description: parts[2]
                })
            }
        }
        return devices
    }

    function refreshConfigDevices() {
        dumpProc.command = ["bash", "-c", "pw-dump 2>/dev/null | python3 -c \"
import json, sys
data = json.load(sys.stdin)
for obj in data:
    if obj.get('type') != 'PipeWire:Interface:Device': continue
    info = obj.get('info',{})
    props = info.get('props',{})
    params = info.get('params',{})
    profiles = params.get('EnumProfile', [])
    if not profiles: continue
    desc = props.get('device.description', props.get('node.description', props.get('device.nick', 'Unknown')))
    cur = params.get('Profile', [{}])[0].get('index', -1) if params.get('Profile') else -1
    print(f'DEVICE:{obj[\\\"id\\\"]}|{desc}|{cur}')
    for p in profiles:
        print(f\\\"PROFILE:{p['index']}|{p['name']}|{p['description']}\\\")
\""]
        dumpProc.running = true
    }

    function setConfigProfile(deviceId, profileIndex) {
        setProc.command = ["pw-cli", "s", String(deviceId), "Profile", '{ "index": ' + String(profileIndex) + ', "save": true }']
        setProc.running = true
        configExpanded = false
        for (var i = 0; i < configDevices.length; i++) {
            if (configDevices[i].id === deviceId) {
                configDevices[i].currentProfile = profileIndex
                configDevices = configDevices.slice()
                break
            }
        }
    }

    onSelDeviceChanged: if (flick && inSection && selSection < 4) flick.scrollToSelection()
    onSelConfigDeviceChanged: if (flick && inSection && selSection === 4) flick.scrollToSelection()
    onSelConfigProfileChanged: if (flick && inSection && selSection === 4 && configExpanded) flick.scrollToSelection()
    onInSectionChanged: if (flick && inSection) flick.scrollToSelection()
    onConfigExpandedChanged: if (flick && inSection && configExpanded) flick.scrollToSelection()

    Process {
        id: dumpProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: configDevices = parseConfigDevices(text)
        }
    }

    Process {
        id: setProc
        running: false
    }

    onVisibleChanged: {
        if (visible) {
            refreshNodeLists()
            refreshConfigDevices()
            mainRect.forceActiveFocus()
            selSection = 0
            inSection = false
            selDevice = 0
            configExpanded = false
        }
    }

    Connections {
        target: Pipewire && Pipewire.nodes
        function onValuesChanged() {
            refreshDebounce.restart()
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
                if (selSection === 4 && inSection) {
                    if (configExpanded) {
                        configExpanded = false
                    } else {
                        configExpanded = true
                        selConfigProfile = 0
                    }
                } else if (selSection === 4 && !inSection) {
                    inSection = true
                } else if (event.modifiers & Qt.ShiftModifier) {
                    if (inSection) {
                        inSection = false
                    } else {
                        selSection = Math.max(selSection - 1, 0)
                    }
                } else if (inSection && selSection < 4) {
                    var maxD = currentModel().length - 1
                    selDevice = Math.min(selDevice + 1, Math.max(0, maxD))
                } else {
                    inSection = true
                    if (selSection < 4) selDevice = 0
                }
                event.accepted = true; break
            case Qt.Key_Backtab:
                if (selSection === 4 && configExpanded) {
                    configExpanded = false
                } else if (inSection) {
                    inSection = false
                }
                event.accepted = true; break
            case Qt.Key_H:
            case Qt.Key_Left:
                if (inSection && selSection < 4) changeVolume(-0.05)
                event.accepted = true; break
            case Qt.Key_L:
            case Qt.Key_Right:
                if (inSection && selSection < 4) changeVolume(0.05)
                event.accepted = true; break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (selSection === 4 && inSection) {
                    if (configExpanded) {
                        var profiles = configDevices[selConfigDevice].profiles
                        if (selConfigProfile >= 0 && selConfigProfile < profiles.length)
                            setConfigProfile(configDevices[selConfigDevice].id, profiles[selConfigProfile].index)
                    } else {
                        configExpanded = true
                        selConfigProfile = 0
                    }
                } else if (!inSection) {
                    inSection = true
                    if (selSection < 4) selDevice = 0
                }
                event.accepted = true; break
            case Qt.Key_J:
            case Qt.Key_Down:
                if (selSection === 4 && configExpanded && inSection) {
                    var profiles = configDevices[selConfigDevice].profiles
                    selConfigProfile = Math.min(selConfigProfile + 1, Math.max(0, profiles.length - 1))
                } else if (selSection === 4 && inSection) {
                    selConfigDevice = Math.min(selConfigDevice + 1, Math.max(0, configDevices.length - 1))
                } else if (inSection && selSection < 4) {
                    var maxD = currentModel().length - 1
                    selDevice = Math.min(selDevice + 1, Math.max(0, maxD))
                } else {
                    selSection = Math.min(selSection + 1, sections.length - 1)
                }
                event.accepted = true; break
            case Qt.Key_K:
            case Qt.Key_Up:
                if (selSection === 4 && configExpanded && inSection) {
                    selConfigProfile = Math.max(selConfigProfile - 1, 0)
                } else if (selSection === 4 && inSection) {
                    selConfigDevice = Math.max(selConfigDevice - 1, 0)
                } else if (inSection && selSection < 4) {
                    selDevice = Math.max(selDevice - 1, 0)
                } else {
                    selSection = Math.max(selSection - 1, 0)
                }
                event.accepted = true; break
            case Qt.Key_Escape:
                if (selSection === 4 && configExpanded) configExpanded = false
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
                        if (selSection < 4 && inSection) {
                            y = 40 + selDevice * 55
                            h = 45
                        } else if (selSection === 4 && inSection) {
                            if (configExpanded) {
                                y = 40 + selConfigDevice * 55 + 45 + selConfigProfile * 30
                                h = 30
                            } else {
                                y = 40 + selConfigDevice * 55
                                h = 45
                            }
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
                            visible: selSection < 4

                            Repeater {
                                model: currentModel()

                                delegate: Item {
                                    id: nodeItem
                                    width: parent.width
                                    height: 45
                                    property real displayedPeak: 0
                                    property real nodeVolume: modelData.audio?.volume ?? 1
                                    property bool nodeMuted: modelData.audio?.muted ?? false

                                    PwNodePeakMonitor {
                                        id: peakMon
                                        node: modelData
                                        enabled: root.visible
                                    }

                                    Timer {
                                        interval: 1000 / Math.max(1, root.peakFps)
                                        running: root.visible
                                        repeat: true
                                        onTriggered: {
                                            var target = nodeMuted ? 0 : Math.min(1, peakMon.peak * nodeVolume)
                                            if (target > displayedPeak) {
                                                displayedPeak = target
                                            } else if (displayedPeak > 0) {
                                                displayedPeak = Math.max(0, displayedPeak - root.peakDecay)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: inSection && index === selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"
                                    }

                                    Text {
                                        id: labelText
                                        text: modelData.description || modelData.name || "(unnamed)"
                                        anchors {
                                            left: parent.left; leftMargin: 10
                                            verticalCenter: parent.verticalCenter
                                        }
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                        elide: Text.ElideRight
                                        width: parent.width * 0.4
                                    }

                                    Rectangle {
                                        id: volBar
                                        anchors {
                                            left: labelText.right; leftMargin: 10
                                            right: pctText.left; rightMargin: 10
                                            verticalCenter: parent.verticalCenter
                                        }
                                        height: 8
                                        color: Qt.alpha(Colors.base00, 1)

                                        Rectangle {
                                            width: parent.width * (modelData.audio?.volume ?? 0)
                                            height: parent.height
                                            color: (modelData.audio?.muted ?? false) ? Qt.alpha(Colors.foreground, 0.75) : Colors.base0d
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            preventStealing: true
                                            onPressed: (mouse) => changeDeviceVolume(index, Math.max(0, Math.min(1, mouse.x / width)))
                                            onMouseXChanged: (mouse) => {
                                                if (pressed) changeDeviceVolume(index, Math.max(0, Math.min(1, mouse.x / width)))
                                            }
                                        }
                                    }

                                    Row {
                                        id: peakRow
                                        anchors {
                                            left: labelText.right; leftMargin: 10
                                            right: pctText.left; rightMargin: 10
                                            top: volBar.bottom; topMargin: 2
                                        }
                                        height: 10
                                        spacing: 10
                                        clip: true

                                        Repeater {
                                            id: peakRepeater
                                            model: Math.max(1, Math.floor((peakRow.width + 10) / 20))

                                            delegate: Rectangle {
                                                width: 10
                                                height: 10
                                                color: index < Math.round(nodeItem.displayedPeak * peakRepeater.count)
                                                       ? Colors.foreground : Qt.alpha(Colors.base0d, 0.75)
                                            }
                                        }
                                    }

                                    Text {
                                        id: pctText
                                        anchors {
                                            right: parent.right; rightMargin: 10
                                            verticalCenter: parent.verticalCenter
                                        }
                                        text: (modelData.audio?.muted ?? false) ? "MUT" : ("  " + Math.round((modelData.audio?.volume ?? 0) * 100)).slice(-3) + "%"
                                        color: (modelData.audio?.muted ?? false) ? Colors.base08 : Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.bold: (modelData.audio?.muted ?? false)

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: toggleDeviceMute(index)
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: selSection === 4

                            Repeater {
                                model: configDevices

                                delegate: Item {
                                    width: parent.width
                                    height: (configExpanded && index === selConfigDevice && inSection)
                                            ? 45 + configDevices[selConfigDevice].profiles.length * 30
                                            : 45

                                    Rectangle {
                                        anchors.fill: parent
                                        color: (!configExpanded && inSection && index === selConfigDevice)
                                               || (configExpanded && inSection && index === selConfigDevice)
                                               ? Qt.alpha(Colors.base01, 0.75) : "transparent"
                                    }

                                    Column {
                                        width: parent.width

                                        Item {
                                            width: parent.width
                                            height: 45

                                            Text {
                                                text: modelData.description
                                                anchors {
                                                    left: parent.left; leftMargin: 10
                                                    top: parent.top; topMargin: 4
                                                }
                                                color: Colors.foreground
                                                font.pixelSize: 16
                                                font.family: "JetBrainsMono Nerd Font"
                                                elide: Text.ElideRight
                                                width: parent.width - 20
                                            }

                                            Text {
                                                function currentProfileDesc() {
                                                    for (var i = 0; i < modelData.profiles.length; i++) {
                                                        if (modelData.profiles[i].index === modelData.currentProfile)
                                                            return modelData.profiles[i].description
                                                    }
                                                    return ""
                                                }
                                                text: currentProfileDesc()
                                                anchors {
                                                    left: parent.left; leftMargin: 10
                                                    top: parent.top; topMargin: 24
                                                }
                                                color: Qt.alpha(Colors.foreground, 0.75)
                                                font.pixelSize: 16
                                                font.family: "JetBrainsMono Nerd Font"
                                                elide: Text.ElideRight
                                                width: parent.width - 20
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (!inSection) { inSection = true }
                                                    if (configExpanded && selConfigDevice === index) {
                                                        configExpanded = false
                                                    } else {
                                                        selConfigDevice = index
                                                        configExpanded = true
                                                        selConfigProfile = 0
                                                    }
                                                }
                                            }
                                        }

                                        Repeater {
                                            model: configExpanded && inSection && index === selConfigDevice
                                                   ? configDevices[selConfigDevice].profiles
                                                   : []

                                            delegate: Rectangle {
                                                width: parent.width
                                                height: 30
                                                color: index === selConfigProfile
                                                       ? Qt.alpha(Colors.base0d, 0.75)
                                                       : Qt.alpha(Colors.base00, 0.75)

                                                Text {
                                                    text: modelData.description || modelData.name
                                                    anchors {
                                                        left: parent.left; leftMargin: 30
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
                                                        if (inSection) {
                                                            setConfigProfile(configDevices[selConfigDevice].id, modelData.index)
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
            }
        }
    }
}
