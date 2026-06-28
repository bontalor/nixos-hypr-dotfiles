import "../../theme"
import "../../util"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

Item {
    id: root
    width: 30 + 10 + textMetrics.width + 20
    height: 30
    clip: true
    visible: true

    property var currentPlayer: {
        void MprisSelector.refreshCounter
        return MprisSelector.selectCurrent(MprisSelector.allPlayers())
    }

    property string trackTitle: currentPlayer ? (currentPlayer.trackTitle ?? "") : ""
    property string trackArtist: currentPlayer ? (currentPlayer.trackArtist ?? "") : ""
    property int playbackState: currentPlayer ? currentPlayer.playbackState : MprisPlaybackState.Stopped

    property int maxChars: 8

    property string displayText: currentPlayer
        ? (trackArtist ? trackArtist + " - " + trackTitle : trackTitle)
        : ""
    property string scrollText: displayText ? displayText + " " + displayText : ""
    property int scrollPos: 0

    property var peakNode: findPeakNode(Pipewire.nodes)
    property var peakLevels: [0, 0, 0, 0, 0, 0, 0, 0]

    function findPeakNode(nodes) {
        if (!nodes) return null
        var vals = nodes.values
        for (var i = 0; i < vals.length; i++) {
            var n = vals[i]
            if (n.audio && !n.isStream && n.isSink) return n
        }
        return null
    }

    onPlaybackStateChanged: {
        if (playbackState === MprisPlaybackState.Playing) startScroll()
        else { scrollPos = 0; scrollTimer.running = false }
    }

    TextMetrics {
        id: textMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPixelSize
        text: "M".repeat(maxChars)
    }

    PwNodePeakMonitor {
        id: peakMon
        node: peakNode
        enabled: root.visible
    }

    Timer {
        interval: 1000 / Theme.peakFps
        running: root.visible && playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: {
            var arr = root.peakLevels.slice()
            if (peakNode) {
                var raw = Math.min(1, peakMon.peak)
                for (var i = 0; i < Theme.peakBands; i++) {
                    var sensitivity = 0.3 + Math.random() * 1.2
                    var decay = 0.01 + Math.random() * 0.05
                    var target = Math.min(1, raw * sensitivity * 1.2)
                    if (target > arr[i]) arr[i] = target
                    else if (arr[i] > 0) arr[i] = Math.max(0, arr[i] - decay)
                }
            } else {
                for (var i = 0; i < Theme.peakBands; i++) arr[i] = 0
            }
            root.peakLevels = arr
        }
    }

    Component.onCompleted: startScroll()

    Rectangle {
        x: contentRow.x - 10
        y: 0
        width: contentRow.width + 20
        height: 30
        color: mouseArea.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
    }

    Item {
        id: contentRow
        anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        height: parent.height

        Item {
            id: vizArea
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 30
            height: 30

            Repeater {
                model: Theme.peakBands
                delegate: Item {
                    property int colIdx: index
                    x: colIdx * 4
                    width: 2
                    height: parent.height

                    Repeater {
                        model: Theme.peakBands
                        delegate: Rectangle {
                            required property int index
                            width: 2
                            height: 2
                            y: parent.height - 2 - index * 4
                            color: Colors.foreground
                            opacity: index === 0 ? 1.0 : (index < Math.round(root.peakLevels[colIdx] * Theme.peakBands) ? 1.0 : 0.0)
                        }
                    }
                }
            }
        }

        Item {
            id: clipArea
            anchors { left: vizArea.right; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
            height: parent.height
            clip: true

            Text {
                id: sliceText
                anchors.verticalCenter: parent.verticalCenter
                x: 0
                text: {
                    if (!root.displayText) return "--------"
                    var chars = Array.from(root.scrollText)
                    var slice = chars.slice(root.scrollPos, root.scrollPos + root.maxChars).join("")
                    while (slice.length < root.maxChars) slice += " "
                    return slice
                }
                font.pixelSize: Theme.fontPixelSize
                font.family: Theme.fontFamily
                color: Colors.foreground
            }
        }
    }

    function startScroll() {
        if (playbackState !== MprisPlaybackState.Playing) return
        if (Array.from(root.displayText).length <= root.maxChars) return
        scrollTimer.start()
    }

    Timer {
        id: scrollTimer
        interval: 250
        repeat: true
        running: false
        onTriggered: {
            var clen = Array.from(root.displayText).length
            if (root.scrollPos >= clen) root.scrollPos = 0
            else root.scrollPos++
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("media")
    }
}