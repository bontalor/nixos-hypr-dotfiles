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

    signal selectDefault(int idx)
    signal changeVolume(int idx, real fraction)
    signal toggleMute(int idx)

    property real displayedPeak: 0
    readonly property real nodeVolume: modelData.audio?.volume ?? 1
    readonly property bool nodeMuted: modelData.audio?.muted ?? false

    PwNodePeakMonitor {
        id: peakMon
        node: devRow.modelData
        enabled: devRow.visible
    }

    readonly property real currentPeak: peakMon.peak

    width: parent.width
    height: devRow.rowHeight

    Rectangle {
        anchors.fill: parent
        color: (devRow.inSection && devRow.index === devRow.selDevice) || nodeHover.containsMouse
               ? Qt.alpha(Colors.selected, Theme.alphaSelected) : "transparent"
    }

    MouseArea {
        id: nodeHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: devRow.selectDefault(devRow.index)
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
        height: 8
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
        height: 10
        spacing: Theme.margin
        clip: true

        Repeater {
            id: peakRepeater
            model: Math.max(1, Math.floor((peakRow.width + Theme.margin) / 20))

            delegate: Rectangle {
                width: 10
                height: 10
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

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: devRow.toggleMute(devRow.index)
        }
    }
}
