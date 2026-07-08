// Subprocess dependencies: pw-dump (device profile discovery), pw-cli
// (profile activation for PipeWire devices).

import "../theme"
import "../components"
import "../util"
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

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

    // --- Named section indices (replace magic numbers) ---
    readonly property int secPlayback: 0
    readonly property int secRecording: 1
    readonly property int secSinks: 2
    readonly property int secSources: 3
    readonly property int secConfig: 4

    // Panel's expandable-config mode drives all keyboard navigation for
    // the Configuration section (expand/collapse, profile selection,
    // scroll-into-view). Only the H/L volume keys are panel-specific.
    expandSection: secConfig
    configItemCount: function() { return root.configDevices.length }
    configProfileCount: function() {
        var dev = root.configDevices[root.selConfigItem]
        return dev ? dev.profiles.length : 0
    }
    configCurrentProfile: function() {
        var dev = root.configDevices[root.selConfigItem]
        if (!dev) return 0
        for (var i = 0; i < dev.profiles.length; i++) {
            if (dev.profiles[i].index === dev.currentProfile) return i
        }
        return 0
    }
    onConfigActivated: {
        var dev = root.configDevices[root.selConfigItem]
        if (dev && root.selConfigProfile < dev.profiles.length)
            root.setConfigProfile(dev.id, dev.profiles[root.selConfigProfile].index)
    }

    currentModelLength: function() { return root.currentModel().length }

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

    Timer {
        interval: 1000 / Math.max(1, Theme.peakFps)
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
                    item.displayedPeak = Math.max(0, item.displayedPeak - Theme.peakDecay)
                }
            }
        }
    }

    function isMonitorNode(n) {
        if (n.name) {
            if (n.name === "quickshell") return true
            if (n.name.startsWith(".quickshell")) return true
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
        case root.secPlayback: return root.playbackStreams
        case root.secRecording: return root.recordingStreams
        case root.secSinks: return root.sinkNodes
        case root.secSources: return root.sourceNodes
        default: return []
        }
    }

    // Enter/click on an output or input device makes it the Pipewire
    // default — streams that follow the default (the WirePlumber norm)
    // move to it immediately. Stream rows have no activation.
    onDeviceActivated: function(idx) {
        var list = root.currentModel()
        if (idx >= list.length) return
        if (root.selSection === root.secSinks)
            Pipewire.preferredDefaultAudioSink = list[idx]
        else if (root.selSection === root.secSources)
            Pipewire.preferredDefaultAudioSource = list[idx]
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

    onShown: refreshConfigDevices()

    // H/L adjust the selected node's volume in the Pipewire sections.
    // Runs before Panel's default handler; accepting the event stops the
    // (no-op) base H/L case from double-handling it.
    onKeyPressed: function(event) {
        switch (event.key) {
        case Qt.Key_H:
        case Qt.Key_Left:
            if (root.inSection && root.selSection < root.secConfig)
                root.changeVolume(-Theme.volumeStep)
            event.accepted = true; break
        case Qt.Key_L:
        case Qt.Key_Right:
            if (root.inSection && root.selSection < root.secConfig)
                root.changeVolume(Theme.volumeStep)
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

            delegate: AudioDeviceRow {
                selSection: root.selSection
                inSection: root.inSection
                selDevice: root.selDevice
                rowHeight: root.rowHeight
                onSelectDefault: (idx) => {
                    if (!root.inSection) root.inSection = true
                    root.selDevice = idx
                    root.deviceActivated(idx)
                }
                onChangeVolume: (idx, fraction) => root.changeDeviceVolume(idx, fraction)
                onToggleMute: (idx) => root.toggleDeviceMute(idx)
            }
        }

        EmptyLabel {
            visible: root.currentModel().length === 0
            text: "No devices"
        }
    }

    // ---- Section 4: PipeWire device configuration ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secConfig

        Repeater {
            model: root.configDevices

            delegate: ConfigExpandItem {
                id: deviceItem

                function currentProfileDesc() {
                    for (var i = 0; i < modelData.profiles.length; i++) {
                        if (modelData.profiles[i].index === modelData.currentProfile)
                            return modelData.profiles[i].description
                    }
                    return ""
                }

                label: modelData.description
                sublabel: currentProfileDesc()
                isSelected: root.inSection && index === root.selConfigItem
                isExpanded: root.configExpanded && index === root.selConfigItem
                profileCount: modelData.profiles.length
                panel: root
                itemIndex: index

                Repeater {
                    model: deviceItem.isExpanded ? modelData.profiles : []

                    delegate: ConfigProfileRow {
                        label: modelData.description || modelData.name
                        isSelected: index === root.selConfigProfile
                        onClicked: {
                            if (root.inSection)
                                root.setConfigProfile(root.configDevices[root.selConfigItem].id, modelData.index)
                        }
                    }
                }
            }
        }

        EmptyLabel {
            visible: root.configDevices.length === 0
            text: "No PipeWire devices"
        }
    }
}
