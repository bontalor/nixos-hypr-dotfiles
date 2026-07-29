// Subprocess dependencies: pw-dump (device profile discovery), pw-cli
// (profile activation for PipeWire devices).

pragma ComponentBehavior: Bound

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

    // autoScroll stays true (default) so Panel.qml fires its onSelDevice/
    // onSelConfigItem/... scroll handlers — we override `scrollToSelection`
    // below to read the real (variable-height) delegate geometry when a
    // row's dropdown is open, and to handle the Configuration section
    // the same way Panel.qml's base would.

    // --- Named section indices (replace magic numbers) ---
    readonly property int secPlayback: 0
    readonly property int secRecording: 1
    readonly property int secSinks: 2
    readonly property int secSources: 3
    readonly property int secConfig: 4

    // --- Per-row action dropdown state (sections 0-3) ---
    // Only one row's dropdown is open at a time so the list stays
    // scannable. State + close/toggle/trigger + keyboard nav all live
    // on the shared DropdownState; the panel supplies deviceActions(idx)
    // (per-row action list) and doDeviceAction(idx, actIdx) (performs
    // the action — DropdownState closes the dropdown after).
    DropdownState {
        id: dropdown
        selectRow: function(idx) { root.selectRow(idx) }
        rowActions: function(idx) { return root.deviceActions(idx) }
        triggerAction: function(idx, actIdx) { root.doDeviceAction(idx, actIdx) }
    }

    // Aliases preserved so existing delegate bindings to
    // `root.expandedDeviceIdx` / `root.selDeviceAction` and the
    // close/toggle/trigger helper functions keep working.
    property int expandedDeviceIdx: dropdown.expandedRowIdx
    property int selDeviceAction: dropdown.selRowAction
    function closeDropdown() { dropdown.close() }
    function toggleDropdown(idx) { dropdown.toggle(idx) }
    function triggerAction(idx, actIdx) { dropdown.trigger(idx, actIdx) }

    function deviceActions(idx) {
        var list = root.currentModel()
        if (idx >= list.length) return []
        var node = list[idx]
        if (!node || !node.audio) return []
        var acts = [{ name: node.audio.muted ? "Unmute" : "Mute", action: "mute" }]
        // Streams can't be set as default — only device nodes.
        if (root.selSection === root.secSinks || root.selSection === root.secSources) {
            var isCurrentDefault = (root.selSection === root.secSinks
                                    && Pipewire.defaultAudioSink === node)
                                || (root.selSection === root.secSources
                                    && Pipewire.defaultAudioSource === node)
            acts.push({ name: isCurrentDefault ? "Default (active)" : "Set Default", action: "default" })
        }
        return acts
    }

    // Performs the action identified by actIdx for row `deviceIdx` —
    // invoked by DropdownState.trigger after the dispatch; the shared
    // state closes the dropdown after this returns.
    function doDeviceAction(deviceIdx, actIdx) {
        var list = root.currentModel()
        if (deviceIdx >= list.length) return
        var node = list[deviceIdx]
        var acts = root.deviceActions(deviceIdx)
        var act = acts[actIdx]
        if (!act) return
        if (act.action === "mute") root.toggleDeviceMute(deviceIdx)
        else if (act.action === "default") {
            if (root.selSection === root.secSinks) Pipewire.preferredDefaultAudioSink = node
            else if (root.selSection === root.secSources) Pipewire.preferredDefaultAudioSource = node
        }
    }

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
        // Bind directly rather than seeding `[]` and updating in an
        // onAllNodesChanged handler — QML change handlers don't fire for
        // the initial property evaluation, so seeding `[]` left nodes
        // present at startup un-tracked until the first Pipewire.nodes
        // change. Direct binding tracks the initial set immediately
        // (this is what OsdModel.qml and bar/widgets/VolumeWidget do).
        objects: root.allNodes.allNodes
    }

    // All Pipewire nodes, categorized.
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
                if (item && item.tickPeak) item.tickPeak()
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
    // The section-0..3 dropdown nav (Tab/Enter/J/K/Escape) lives here so
    // we can pre-empt Panel's default H/L/Tab/Enter handling when the
    // dropdown is open. Config section stays on the panel's
    // expandSection machinery; interactions there are untouched.
    onKeyPressed: function(event) {
        // H/L volume nudge works only when a row is selected in the
        // device/stream sections, not inside an open dropdown (J/K owns
        // vertical there). Accept unconditionally so Panel's no-op H/L
        // default doesn't double-handle.
        if (root.inSection && root.selSection < root.secConfig) {
            if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                if (root.expandedDeviceIdx !== root.selDevice) root.changeVolume(-Theme.volumeStep)
                event.accepted = true; return
            }
            if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                if (root.expandedDeviceIdx !== root.selDevice) root.changeVolume(Theme.volumeStep)
                event.accepted = true; return
            }
        }

        // Section-0..3 dropdown nav. Pre-empts PanelNav's Tab/Enter (which
        // would descend into the section or fire deviceActivated) so Enter
        // opens the dropdown instead of immediately setting the default
        // — matches the rest of the shell's dropdown UX.
        if (root.inSection && root.selSection < root.secConfig) {
            if (dropdown.handleKey(event, root.selDevice)) return
        }
    }

    // Closing the panel or leaving the section closes any open dropdown.
    onVisibleChanged: if (!visible) root.closeDropdown()
    onSelSectionChanged: root.closeDropdown()

    // Variable-height scroll: read the real delegate geometry from the
    // Repeater (open dropdowns add Theme.searchRowHeight per action).
    onSelDeviceActionChanged: Qt.callLater(root.scrollToSelection)
    onExpandedDeviceIdxChanged: Qt.callLater(root.scrollToSelection)

    function scrollToSelection() {
        if (!root.inSection) return
        // Configuration section's expandable rows are fixed-stride —
        // the math is identical to Panel.qml's base, so share the
        // Scroll.expandConfigTarget helper instead of duplicating it.
        if (root.selSection === root.secConfig) {
            var t = Scroll.expandConfigTarget(
                root.headerHeight, root.colSpacing,
                root.rowHeight, Theme.searchRowHeight,
                root.selConfigItem, root.configExpanded,
                root.selConfigProfile)
            root.scrollToVisible(t.y, t.h)
            return
        }
        if (root.selSection > root.secSources) return
        var baseY = nodeColumn.y
        if (root.selDevice < nodeRepeater.count) {
            var item = nodeRepeater.itemAt(root.selDevice)
            if (item) {
                root.scrollToVisible(baseY + item.y, item.height)
                // Keep the highlighted action row visible inside the
                // expanded dropdown by extending the target height.
                if (root.expandedDeviceIdx === root.selDevice && root.selDeviceAction >= 0) {
                    var actionY = baseY + item.y + root.rowHeight
                                 + root.selDeviceAction * Theme.searchRowHeight
                    root.scrollToVisible(actionY, Theme.searchRowHeight)
                }
            }
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
        id: nodeColumn
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
                actions: root.deviceActions(index)
                dropdownOpen: root.expandedDeviceIdx === index
                selActionIndex: root.expandedDeviceIdx === index ? root.selDeviceAction : -1
                // Hoisted — DropdownState.toggle stomps inSection +
                // selDevice via the panel's `selectRow` callback.
                onDropdownToggled: root.toggleDropdown(index)
                onChangeVolume: (idx, fraction) => root.changeDeviceVolume(idx, fraction)
                onActionTriggered: (idx) => root.triggerAction(index, idx)
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
                required property var modelData
                required property int index

                function currentProfileDesc() {
                    for (var i = 0; i < deviceItem.modelData.profiles.length; i++) {
                        if (deviceItem.modelData.profiles[i].index === deviceItem.modelData.currentProfile)
                            return deviceItem.modelData.profiles[i].description
                    }
                    return ""
                }

                label: deviceItem.modelData.description
                sublabel: currentProfileDesc()
                isSelected: root.inSection && index === root.selConfigItem
                isExpanded: root.configExpanded && index === root.selConfigItem
                profileCount: deviceItem.modelData.profiles.length
                panel: root
                itemIndex: index

                Repeater {
                    model: deviceItem.isExpanded ? deviceItem.modelData.profiles : []

                    delegate: ConfigProfileRow {
                        id: profileRow
                        required property var modelData
                        required property int index
                        label: profileRow.modelData.description || profileRow.modelData.name
                        isSelected: index === root.selConfigProfile
                        onClicked: {
                            if (root.inSection)
                                root.setConfigProfile(root.configDevices[root.selConfigItem].id, profileRow.modelData.index)
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