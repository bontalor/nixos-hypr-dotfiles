import "../theme"
import "../util"
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

    readonly property int secConfig: 4

    PwObjectTracker {
        id: nodeTracker
        objects: []
    }

    // All Pipewire nodes, categorized. nodeTracker.objects is updated
    // in onAllNodesChanged (not inside the binding) to avoid the
    // side-effect-in-binding anti-pattern.
    property var allNodes: {
        var raw = Pipewire.nodes
        var vals = raw && raw.values ? raw.values : []
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
        return { playbackStreams: pbs, recordingStreams: rcs, sinkNodes: sks, sourceNodes: srcs, allNodes: vals }
    }

    onAllNodesChanged: nodeTracker.objects = allNodes.allNodes

    property var playbackStreams: allNodes.playbackStreams
    property var recordingStreams: allNodes.recordingStreams
    property var sinkNodes: allNodes.sinkNodes
    property var sourceNodes: allNodes.sourceNodes

    property var configDevices: []
    property int selConfigDevice: 0
    property bool configExpanded: false
    property int selConfigProfile: 0

    // VU-meter peak polling. Uses Theme.peakFps (was a local copy).
    readonly property int peakFps: Theme.peakFps
    readonly property real peakDecay: 0.05

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

    // Parse pw-dump JSON output directly in JS — no python, no jq, no
    // intermediate text format. Quickshell 0.3.0 ships no PipeWire
    // device-profile API, so `pw-dump` is the only source. `pw-cli s
    // <id> Profile '{...}'` sets the selected profile.
    function parseConfigDevices(text) {
        var data
        try { data = JSON.parse(text) } catch (e) { return [] }
        var devices = []
        for (var i = 0; i < data.length; i++) {
            var obj = data[i]
            if (obj.type !== "PipeWire:Interface:Device") continue
            var info = obj.info || {}
            var props = info.props || {}
            var params = info.params || {}
            var profiles = params.EnumProfile
            if (!profiles || !profiles.length) continue
            var desc = props["device.description"]
                || props["node.description"]
                || props["device.nick"]
                || "Unknown"
            var cur = (params.Profile && params.Profile.length)
                ? params.Profile[0].index : -1
            var device = { id: obj.id, description: desc, currentProfile: cur, profiles: [] }
            for (var j = 0; j < profiles.length; j++) {
                device.profiles.push({
                    index: profiles[j].index,
                    name: profiles[j].name,
                    description: profiles[j].description
                })
            }
            devices.push(device)
        }
        return devices
    }

    function refreshConfigDevices() {
        dumpProc.command = ["pw-dump"]
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
        if (root.selSection < root.secConfig) {
            y = root.headerHeight + root.colSpacing + root.selDevice * (root.rowHeight + root.colSpacing)
            h = root.rowHeight
        } else if (root.configExpanded) {
            y = root.headerHeight + root.colSpacing + root.selConfigDevice * (root.rowHeight + root.colSpacing) + root.rowHeight + root.selConfigProfile * Theme.searchRowHeight
            h = Theme.searchRowHeight
        } else {
            y = root.headerHeight + root.colSpacing + root.selConfigDevice * (root.rowHeight + root.colSpacing)
            h = root.rowHeight
        }
        root.scrollToVisible(y, h)
    }

    onShown: {
        refreshConfigDevices()
        root.configExpanded = false
    }

    onKeyPressed: function(event) {
        switch (event.key) {
        case Qt.Key_Tab:
            if (root.selSection === root.secConfig && root.inSection) {
                if (root.configExpanded) root.configExpanded = false
                else { root.configExpanded = true; root.selConfigProfile = 0 }
            } else if (root.selSection === root.secConfig && !root.inSection) {
                root.inSection = true
            } else if (event.modifiers & Qt.ShiftModifier) {
                if (root.inSection) root.inSection = false
                else root.selSection = Scroll.clamp(root.selSection - 1, 0, root.sections.length - 1)
            } else if (root.inSection) {
                root.selDevice = Scroll.step(root.selDevice, 1, root.currentModel().length)
            } else {
                root.inSection = true; root.selDevice = 0
            }
            event.accepted = true; break
        case Qt.Key_Backtab:
            if (root.selSection === root.secConfig && root.configExpanded) root.configExpanded = false
            else if (root.inSection) root.inSection = false
            event.accepted = true; break
        case Qt.Key_H:
        case Qt.Key_Left:
            if (root.inSection && root.selSection < root.secConfig) root.changeVolume(-Theme.volumeStep)
            event.accepted = true; break
        case Qt.Key_L:
        case Qt.Key_Right:
            if (root.inSection && root.selSection < root.secConfig) root.changeVolume(Theme.volumeStep)
            event.accepted = true; break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (root.selSection === root.secConfig && root.inSection) {
                if (root.configExpanded && root.selConfigDevice < root.configDevices.length) {
                    var profiles = root.configDevices[root.selConfigDevice].profiles
                    if (root.selConfigProfile >= 0 && root.selConfigProfile < profiles.length)
                        root.setConfigProfile(root.configDevices[root.selConfigDevice].id, profiles[root.selConfigProfile].index)
                } else if (!root.configExpanded && root.configDevices.length > 0) {
                    root.configExpanded = true; root.selConfigProfile = 0
                }
            } else if (!root.inSection) {
                root.inSection = true
                if (root.selSection < root.secConfig) root.selDevice = 0
            }
            event.accepted = true; break
        case Qt.Key_J:
        case Qt.Key_Down:
            if (root.selSection === root.secConfig && root.configExpanded && root.inSection && root.selConfigDevice < root.configDevices.length) {
                var profiles = root.configDevices[root.selConfigDevice].profiles
                root.selConfigProfile = Scroll.clamp(root.selConfigProfile + 1, 0, profiles.length - 1)
            } else if (root.selSection === root.secConfig && root.inSection) {
                root.selConfigDevice = Scroll.clamp(root.selConfigDevice + 1, 0, Math.max(0, root.configDevices.length - 1))
            } else if (root.inSection && root.selSection < root.secConfig) {
                root.selDevice = Scroll.step(root.selDevice, 1, root.currentModel().length)
            } else {
                root.selSection = Scroll.clamp(root.selSection + 1, 0, root.sections.length - 1)
            }
            event.accepted = true; break
        case Qt.Key_K:
        case Qt.Key_Up:
            if (root.selSection === root.secConfig && root.configExpanded && root.inSection) {
                if (root.selConfigDevice < root.configDevices.length) {
                    var profiles = root.configDevices[root.selConfigDevice].profiles
                    root.selConfigProfile = Scroll.clamp(root.selConfigProfile - 1, 0, profiles.length - 1)
                }
            } else if (root.selSection === root.secConfig && root.inSection) {
                root.selConfigDevice = Scroll.clamp(root.selConfigDevice - 1, 0, Math.max(0, root.configDevices.length - 1))
            } else if (root.inSection && root.selSection < root.secConfig) {
                root.selDevice = Scroll.step(root.selDevice, -1, root.currentModel().length)
            } else {
                root.selSection = Scroll.clamp(root.selSection - 1, 0, root.sections.length - 1)
            }
            event.accepted = true; break
        case Qt.Key_Escape:
            if (root.selSection === root.secConfig && root.configExpanded) root.configExpanded = false
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
        visible: root.selSection < root.secConfig

        Repeater {
            id: nodeRepeater
            model: root.currentModel()

            delegate: Item {
                id: nodeItem
                width: parent.width
                height: root.rowHeight
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
                    color: (root.inSection && index === root.selDevice) || nodeHover.containsMouse ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
                }

                MouseArea {
                    id: nodeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                ThemeText {
                    id: labelText
                    text: modelData.description || modelData.name || "(unnamed)"
                    anchors {
                        left: parent.left; leftMargin: Theme.margin
                        verticalCenter: parent.verticalCenter
                    }
                    elide: Text.ElideRight
                    width: parent.width * 0.4
                }

                Rectangle {
                    id: volBar
                    anchors {
                        left: labelText.right; leftMargin: Theme.margin
                        right: pctText.left; rightMargin: Theme.margin
                        verticalCenter: parent.verticalCenter
                    }
                    height: 8
                    color: Qt.alpha(Colors.base00, 1)

                    Rectangle {
                        width: parent.width * (modelData.audio?.volume ?? 0)
                        height: parent.height
                        color: (modelData.audio?.muted ?? false) ? Qt.alpha(Colors.foreground, Theme.alphaBackground) : Colors.base0d
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
                        left: labelText.right; leftMargin: Theme.margin
                        right: pctText.left; rightMargin: Theme.margin
                        top: volBar.bottom; topMargin: 2
                    }
                    height: 10
                    spacing: Theme.margin
                    clip: true

                    Repeater {
                        id: peakRepeater
                        model: Math.max(1, Math.floor((peakRow.width + Theme.margin) / 20))

                        delegate: Rectangle {
                            width: 10
                            height: 10
                            color: index < Math.round(nodeItem.displayedPeak * peakRepeater.count)
                                   ? Colors.foreground : Qt.alpha(Colors.foreground, 0.25)
                        }
                    }
                }

                ThemeText {
                    id: pctText
                    anchors {
                        right: parent.right; rightMargin: Theme.margin
                        verticalCenter: parent.verticalCenter
                    }
                    text: (modelData.audio?.muted ?? false) ? "MUT" : FormatUtil.padNum(Math.round((modelData.audio?.volume ?? 0) * 100), 3) + "%"
                    color: (modelData.audio?.muted ?? false) ? Colors.critical : Colors.foreground
                    font.bold: (modelData.audio?.muted ?? false)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleDeviceMute(index)
                    }
                }
            }
        }

        ThemeText {
            width: parent.width
            height: Theme.searchRowHeight
            visible: root.currentModel().length === 0
            text: "No devices"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
        }
    }

    // ---- Section 4: PipeWire device configuration ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secConfig

        Repeater {
            model: root.configDevices

            delegate: Item {
                width: parent.width
                height: (root.configExpanded && index === root.selConfigDevice && root.inSection && root.selConfigDevice < root.configDevices.length)
                        ? root.rowHeight + root.configDevices[root.selConfigDevice].profiles.length * Theme.searchRowHeight
                        : root.rowHeight

                Rectangle {
                    anchors.fill: parent
                    color: (root.inSection && index === root.selConfigDevice) || configDevMouse.containsMouse
                           ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
                }

                Column {
                    width: parent.width

                    Item {
                        width: parent.width
                        height: root.rowHeight

                        ThemeText {
                            text: modelData.description
                            anchors {
                                left: parent.left; leftMargin: Theme.margin
                                top: parent.top; topMargin: 4
                            }
                            elide: Text.ElideRight
                            width: parent.width - 2 * Theme.margin
                        }

                        ThemeText {
                            function currentProfileDesc() {
                                for (var i = 0; i < modelData.profiles.length; i++) {
                                    if (modelData.profiles[i].index === modelData.currentProfile)
                                        return modelData.profiles[i].description
                                }
                                return ""
                            }
                            text: currentProfileDesc()
                            anchors {
                                left: parent.left; leftMargin: Theme.margin
                                top: parent.top; topMargin: 24
                            }
                            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                            elide: Text.ElideRight
                            width: parent.width - 2 * Theme.margin
                        }

                        MouseArea {
                            id: configDevMouse
                            anchors.fill: parent
                            hoverEnabled: true
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
                            height: Theme.searchRowHeight
                            color: index === root.selConfigProfile
                                   ? Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)
                                   : configProfileMouse.containsMouse
                                       ? Qt.alpha(Colors.base01, Theme.alphaSelected)
                                       : Qt.alpha(Colors.base00, Theme.alphaBackground)

                            ThemeText {
                                text: modelData.description || modelData.name
                                anchors {
                                    left: parent.left; leftMargin: 3 * Theme.margin
                                    verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: configProfileMouse
                                anchors.fill: parent
                                hoverEnabled: true
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

        ThemeText {
            width: parent.width
            height: Theme.searchRowHeight
            visible: root.configDevices.length === 0
            text: "No PipeWire devices"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
        }
    }
}
