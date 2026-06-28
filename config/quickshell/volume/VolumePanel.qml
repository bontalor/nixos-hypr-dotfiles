import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Widgets

Panel {
    id: root
    title: "Volume Control"
    sections: [
        { name: "Playback" },
        { name: "Recording" },
        { name: "Output Devices" },
        { name: "Input Devices" },
        { name: "Configuration" }
    ]

    useDefaultKeys: false
    autoScroll: false

    PwObjectTracker {
        id: nodeTracker
        objects: []
    }

    property var allNodes: {
        var raw = Pipewire.nodes
        var vals = raw && raw.values ? raw.values : []
        nodeTracker.objects = vals
        var pbs = [], rcs = [], sks = [], srcs = []
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
        return { playbackStreams: pbs, recordingStreams: rcs, sinkNodes: sks, sourceNodes: srcs }
    }

    property var playbackStreams: allNodes.playbackStreams
    property var recordingStreams: allNodes.recordingStreams
    property var sinkNodes: allNodes.sinkNodes
    property var sourceNodes: allNodes.sourceNodes

    property var configDevices: []
    property int selConfigDevice: 0
    property bool configExpanded: false
    property int selConfigProfile: 0

    property int peakFps: 20
    property real peakDecay: 0.05

    Timer {
        interval: 1000 / Math.max(1, root.peakFps)
        running: root.visible
        repeat: true
        onTriggered: {
            if (!nodeRepeater) return
            for (var i = 0; i < nodeRepeater.count; i++) {
                var item = nodeRepeater.itemAt(i)
                if (!item) continue
                var target = item.nodeMuted ? 0 : Math.min(1, item.currentPeak * item.nodeVolume)
                if (target > item.displayedPeak) {
                    item.displayedPeak = target
                } else if (item.displayedPeak > 0) {
                    item.displayedPeak = Math.max(0, item.displayedPeak - root.peakDecay)
                }
            }
        }
    }

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

    function currentModel() {
        switch (root.selSection) {
        case 0: return root.playbackStreams
        case 1: return root.recordingStreams
        case 2: return root.sinkNodes
        case 3: return root.sourceNodes
        default: return []
        }
    }

    function changeVolume(delta) {
        var list = currentModel()
        if (root.selDevice >= list.length) return
        var node = list[root.selDevice]
        if (node && node.audio)
            node.audio.volume = Math.max(0, Math.min(1, node.audio.volume + delta))
    }

    function changeDeviceVolume(idx, fraction) {
        var list = currentModel()
        if (idx >= list.length) return
        var node = list[idx]
        if (node && node.audio)
            node.audio.volume = Math.max(0, Math.min(1, fraction))
    }

    function toggleDeviceMute(idx) {
        var list = currentModel()
        if (idx >= list.length) return
        var node = list[idx]
        if (node && node.audio) node.audio.muted = !node.audio.muted
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
                var p = line.substring(8).split('|')
                current.profiles.push({
                    index: parseInt(p[0]),
                    name: p[1],
                    description: p[2]
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
        root.configExpanded = false
        for (var i = 0; i < root.configDevices.length; i++) {
            if (root.configDevices[i].id === deviceId) {
                root.configDevices[i].currentProfile = profileIndex
                root.configDevices = root.configDevices.slice()
                break
            }
        }
    }

    onSelDeviceChanged: root.scrollSelectionIntoView()
    onSelConfigDeviceChanged: root.scrollSelectionIntoView()
    onSelConfigProfileChanged: root.scrollSelectionIntoView()
    onInSectionChanged: if (root.inSection) root.scrollSelectionIntoView()
    onConfigExpandedChanged: if (root.inSection && root.configExpanded) root.scrollSelectionIntoView()

    function scrollSelectionIntoView() {
        if (!root.inSection) return
        var y, h
        if (root.selSection < 4) {
            y = root.headerHeight + root.colSpacing + root.selDevice * (root.rowHeight + root.colSpacing)
            h = root.rowHeight
        } else if (root.configExpanded) {
            y = root.headerHeight + root.colSpacing + root.selConfigDevice * (root.rowHeight + root.colSpacing) + root.rowHeight + root.selConfigProfile * 30
            h = 30
        } else {
            y = root.headerHeight + root.colSpacing + root.selConfigDevice * (root.rowHeight + root.colSpacing)
            h = root.rowHeight
        }
        root.flick.scrollToVisible(y, h)
    }

    onShown: {
        refreshConfigDevices()
        root.configExpanded = false
    }

    onKeyPressed: function(event) {
        switch (event.key) {
        case Qt.Key_Tab:
            if (root.selSection === 4 && root.inSection) {
                if (root.configExpanded) root.configExpanded = false
                else { root.configExpanded = true; root.selConfigProfile = 0 }
            } else if (root.selSection === 4 && !root.inSection) {
                root.inSection = true
            } else if (event.modifiers & Qt.ShiftModifier) {
                if (root.inSection) root.inSection = false
                else root.selSection = Math.max(root.selSection - 1, 0)
            } else if (root.inSection) {
                root.selDevice = Math.min(root.selDevice + 1, Math.max(0, root.currentModel().length - 1))
            } else {
                root.inSection = true
                root.selDevice = 0
            }
            event.accepted = true; break
        case Qt.Key_Backtab:
            if (root.selSection === 4 && root.configExpanded) root.configExpanded = false
            else if (root.inSection) root.inSection = false
            event.accepted = true; break
        case Qt.Key_H:
        case Qt.Key_Left:
            if (root.inSection && root.selSection < 4) root.changeVolume(-0.05)
            event.accepted = true; break
        case Qt.Key_L:
        case Qt.Key_Right:
            if (root.inSection && root.selSection < 4) root.changeVolume(0.05)
            event.accepted = true; break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (root.selSection === 4 && root.inSection) {
                if (root.configExpanded && root.selConfigDevice < root.configDevices.length) {
                    var profiles = root.configDevices[root.selConfigDevice].profiles
                    if (root.selConfigProfile >= 0 && root.selConfigProfile < profiles.length)
                        root.setConfigProfile(root.configDevices[root.selConfigDevice].id, profiles[root.selConfigProfile].index)
                } else if (!root.configExpanded && root.configDevices.length > 0) {
                    root.configExpanded = true
                    root.selConfigProfile = 0
                }
            } else if (!root.inSection) {
                root.inSection = true
                if (root.selSection < 4) root.selDevice = 0
            }
            event.accepted = true; break
        case Qt.Key_J:
        case Qt.Key_Down:
            if (root.selSection === 4 && root.configExpanded && root.inSection && root.selConfigDevice < root.configDevices.length) {
                var profiles = root.configDevices[root.selConfigDevice].profiles
                root.selConfigProfile = Math.min(root.selConfigProfile + 1, Math.max(0, profiles.length - 1))
            } else if (root.selSection === 4 && root.inSection) {
                root.selConfigDevice = Math.max(0, Math.min(root.selConfigDevice + 1, Math.max(0, root.configDevices.length - 1)))
            } else if (root.inSection && root.selSection < 4) {
                root.selDevice = Math.min(root.selDevice + 1, Math.max(0, root.currentModel().length - 1))
            } else {
                root.selSection = Math.min(root.selSection + 1, root.sections.length - 1)
            }
            event.accepted = true; break
        case Qt.Key_K:
        case Qt.Key_Up:
            if (root.selSection === 4 && root.configExpanded && root.inSection) {
                root.selConfigProfile = Math.max(root.selConfigProfile - 1, 0)
            } else if (root.selSection === 4 && root.inSection) {
                root.selConfigDevice = Math.max(root.selConfigDevice - 1, 0)
            } else if (root.inSection && root.selSection < 4) {
                root.selDevice = Math.max(root.selDevice - 1, 0)
            } else {
                root.selSection = Math.max(root.selSection - 1, 0)
            }
            event.accepted = true; break
        case Qt.Key_Escape:
            if (root.selSection === 4 && root.configExpanded) root.configExpanded = false
            else if (root.inSection) root.inSection = false
            else root.visible = false
            event.accepted = true; break
        }
    }

    Process {
        id: dumpProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.configDevices = root.parseConfigDevices(text)
        }
    }

    Process {
        id: setProc
        running: false
    }

    // ---- Sections 0-3: Pipewire node lists ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection < 4

        Repeater {
            id: nodeRepeater
            model: root.currentModel()

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

                property real currentPeak: peakMon.peak

                Rectangle {
                    anchors.fill: parent
                    color: root.inSection && index === root.selDevice ? Qt.alpha(Colors.base01, 0.75) : "transparent"
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
                        onPressed: (mouse) => root.changeDeviceVolume(index, Math.max(0, Math.min(1, mouse.x / width)))
                        onMouseXChanged: (mouse) => {
                            if (pressed) root.changeDeviceVolume(index, Math.max(0, Math.min(1, mouse.x / width)))
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
                        onClicked: root.toggleDeviceMute(index)
                    }
                }
            }
        }

        Text {
            width: parent.width
            height: 30
            visible: root.currentModel().length === 0
            text: "Nothing to show"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, 0.75)
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
        }
    }

    // ---- Section 4: PipeWire device configuration ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 4

        Repeater {
            model: root.configDevices

            delegate: Item {
                width: parent.width
                height: (root.configExpanded && index === root.selConfigDevice && root.inSection && root.selConfigDevice < root.configDevices.length)
                        ? 45 + root.configDevices[root.selConfigDevice].profiles.length * 30
                        : 45

                Rectangle {
                    anchors.fill: parent
                    color: ((!root.configExpanded && root.inSection && index === root.selConfigDevice)
                            || (root.configExpanded && root.inSection && index === root.selConfigDevice))
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
                                if (!root.inSection) root.inSection = true
                                if (root.configExpanded && root.selConfigDevice === index) {
                                    root.configExpanded = false
                                } else {
                                    root.selConfigDevice = index
                                    root.configExpanded = true
                                    root.selConfigProfile = 0
                                }
                            }
                        }
                    }

                    Repeater {
                        model: root.configExpanded && root.inSection && index === root.selConfigDevice && root.selConfigDevice < root.configDevices.length
                               ? root.configDevices[root.selConfigDevice].profiles
                               : []

                        delegate: Rectangle {
                            width: parent.width
                            height: 30
                            color: index === root.selConfigProfile
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
                                    if (root.inSection)
                                        root.setConfigProfile(root.configDevices[root.selConfigDevice].id, modelData.index)
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            height: 30
            visible: root.configDevices.length === 0
            text: "No PipeWire devices"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, 0.75)
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
        }
    }
}