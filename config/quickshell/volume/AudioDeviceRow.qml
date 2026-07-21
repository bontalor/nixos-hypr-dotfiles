// One Pipewire node row in VolumePanel, with an inline action dropdown
// that opens below it (Mute/Unmute, plus "Set Default" for device
// sections). The panel owns the expanded-row/selAction state so keyboard
// focus stays synchronised with the section's selDevice; this widget
// renders the highlight + the click surface.
//
// Layout (Column):
//   ┌ header row: name | volume bar + peak | pct/mono indicator ┐
//   └ action list (when open): searchRowHeight rows              ┘
//
// Signals:
//   dropdownToggled()      row header click — caller opens/closes
//                           the dropdown for this item
//   changeVolume(idx, frac) bar drag (mouse)
//   actionTriggered(idx)   action row click or keyboard Enter
//
// Properties driving the dropdown (all set by the panel):
//   actions         list of { name, action }
//   dropdownOpen    whether the dropdown list is currently shown
//   selActionIndex  keyboard-highlighted action, -1 = none

import "../components"
import "../theme"
import "../util"
import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: devRow

    required property var modelData
    required property int index
    property bool inSection: false
    readonly property bool isDefault: (devRow.selSection === 2 && Pipewire.defaultAudioSink === devRow.modelData)
                                   || (devRow.selSection === 3 && Pipewire.defaultAudioSource === devRow.modelData)
    property int selDevice: -1
    property int selSection: 0
    property real rowHeight: Theme.rowHeight

    // Dropdown state — owned by the panel (so keyboard nav can drive
    // selection), mirrored here only for render.
    property var actions: []
    property bool dropdownOpen: false
    property int selActionIndex: -1

    signal dropdownToggled()
    signal changeVolume(int idx, real fraction)
    signal actionTriggered(int idx)

    PwNodePeakMonitor {
        id: peakMon
        node: devRow.modelData
        enabled: devRow.visible
    }

    readonly property real currentPeak: peakMon.peak
    property real displayedPeak: 0
    readonly property real nodeVolume: modelData.audio?.volume ?? 1
    readonly property bool nodeMuted: modelData.audio?.muted ?? false
    readonly property bool hasActions: devRow.actions.length > 0

    width: parent.width
    height: devRow.rowHeight
            + (devRow.dropdownOpen && devRow.hasActions
               ? devRow.actions.length * Theme.searchRowHeight
               : 0)

    // Per-frame peak decay; the panel owns the Timer that drives this so
    // one Timer walks all visible rows instead of N Timers.
    function tickPeak() {
        var target = devRow.nodeMuted ? 0 : Math.min(1, devRow.currentPeak * devRow.nodeVolume)
        if (target > devRow.displayedPeak) devRow.displayedPeak = target
        else if (devRow.displayedPeak > 0)
            devRow.displayedPeak = Math.max(0, devRow.displayedPeak - Theme.peakDecay)
    }

    // --- Header row ---
    Rectangle {
        id: headerBg
        width: parent.width
        height: devRow.rowHeight
        color: (devRow.inSection && devRow.index === devRow.selDevice) || nodeHover.containsMouse
               ? Qt.alpha(Colors.selected, Theme.alphaSelected) : "transparent"

        // Whole-header click toggles the dropdown when actions exist;
        // when there are none (e.g. monitor-only nodes) clicking is a
        // no-op so focus doesn't drift.
        MouseArea {
            id: nodeHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: devRow.hasActions ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (devRow.hasActions) devRow.dropdownToggled()
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
            // Default device stays colored (success + bold) so users can
            // tell which sink/source Pipewire will route new streams to,
            // even though Enter no longer immediately swaps it.
            color: devRow.isDefault ? Colors.success : Colors.foreground
            font.bold: devRow.isDefault
        }

        Rectangle {
            id: volBar
            anchors {
                left: labelText.right; leftMargin: Theme.margin
                right: pctText.left; rightMargin: Theme.margin
                verticalCenter: parent.verticalCenter
            }
            height: Theme.meterHeight
            color: Qt.alpha(Colors.surface, 1)

            Rectangle {
                width: parent.width * (modelData.audio?.volume ?? 0)
                height: parent.height
                color: (modelData.audio?.muted ?? false) ? Qt.alpha(Colors.foreground, Theme.alphaBackground) : Colors.accent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onPressed: (mouse) => devRow.changeVolume(devRow.index, Math.max(0, Math.min(1, mouse.x / width)))
                onMouseXChanged: (mouse) => {
                    if (pressed) devRow.changeVolume(devRow.index, Math.max(0, Math.min(1, mouse.x / width)))
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
            height: Theme.meterHeight
            spacing: Theme.margin
            clip: true

            Repeater {
                id: peakRepeater
                model: Math.max(1, Math.floor((peakRow.width + Theme.margin) / 20))

                delegate: Rectangle {
                    width: Theme.meterHeight
                    height: Theme.meterHeight
                    color: index < Math.round(devRow.displayedPeak * peakRepeater.count)
                           ? Colors.foreground : Qt.alpha(Colors.foreground, Theme.alphaInactive)
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
        }
    }

    // --- Action dropdown (open below the header) ---
    Column {
        width: parent.width
        y: devRow.rowHeight
        visible: devRow.dropdownOpen && devRow.hasActions
        height: devRow.dropdownOpen && devRow.hasActions
                ? devRow.actions.length * Theme.searchRowHeight
                : 0

        Repeater {
            model: devRow.actions

            delegate: Rectangle {
                width: parent.width
                height: Theme.searchRowHeight
                color: index === devRow.selActionIndex
                       ? Qt.alpha(Colors.accent, Theme.alphaSectionHeader)
                       : actHover.containsMouse
                         ? Qt.alpha(Colors.selected, Theme.alphaSelected)
                         : Qt.alpha(Colors.surface, Theme.alphaBackground)

                ThemeText {
                    text: modelData.name
                    anchors {
                        left: parent.left; leftMargin: 3 * Theme.margin
                        right: parent.right; rightMargin: Theme.margin
                        verticalCenter: parent.verticalCenter
                    }
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: actHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: devRow.actionTriggered(index)
                }
            }
        }
    }
}