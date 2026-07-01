import "../../theme"
import "../../util"
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root
    width: 30 + Theme.margin + textMetrics.width + 2 * Theme.margin
    height: Theme.barHeight
    clip: true

    property var currentPlayer: MprisSelector.currentPlayer

    property string trackTitle: currentPlayer ? (currentPlayer.trackTitle ?? "") : ""
    property string trackArtist: currentPlayer ? (currentPlayer.trackArtist ?? "") : ""
    property int playbackState: currentPlayer ? currentPlayer.playbackState : MprisPlaybackState.Stopped

    property int maxChars: 8

    property string displayText: currentPlayer
        ? (trackArtist ? trackArtist + " - " + trackTitle : trackTitle)
        : ""

    property var peakLevels: Array(Theme.peakBands).fill(0)

    onPlaybackStateChanged: {
        if (playbackState !== MprisPlaybackState.Playing)
            root.peakLevels = Array(Theme.peakBands).fill(0)
    }

    // Fixed clip width — 8 "M" chars, same as the original maxChars approach.
    TextMetrics {
        id: textMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPixelSize
        text: "M".repeat(maxChars)
    }

    // Scroll only when playing and text overflows the clip area.
    // t1.implicitWidth is the actual rendered pixel width — used instead of
    // TextMetrics so the loop distance is guaranteed to match the rendered text.
    property bool needsScroll: playbackState === MprisPlaybackState.Playing
        && root.displayText !== ""
        && t1.implicitWidth > textMetrics.width

    function resetScroll() {
        scrollAnim.stop()
        scrollRow.x = 0
        if (needsScroll) scrollAnim.start()
    }

    onNeedsScrollChanged: resetScroll()
    onDisplayTextChanged: resetScroll()

    // Peak visualizer — decorative, not a real spectrum.
    // Raw peak comes from OsdModel.sinkPeak (one shared PwNodePeakMonitor
    // for all screens) instead of a per-instance monitor.
    Timer {
        interval: 1500 / Theme.peakFps
        running: root.visible && playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: {
            var arr = root.peakLevels.slice()
            var raw = Math.min(1, MprisSelector.sinkPeak)
            for (let i = 0; i < Theme.peakBands; i++) {
                var sensitivity = 0.3 + Math.random() * 1.2
                var decay = 0.01 + Math.random() * 0.05
                var target = Math.min(1, raw * sensitivity * 1.2)
                if (target > arr[i]) arr[i] = target
                else if (arr[i] > 0) arr[i] = Math.max(0, arr[i] - decay)
            }
            root.peakLevels = arr
        }
    }

    Rectangle {
        x: contentRow.x - Theme.margin
        y: 0
        width: contentRow.width + 2 * Theme.margin
        height: Theme.barHeight
        color: mouseArea.containsMouse
            ? Qt.alpha(Colors.foreground, Theme.alphaHover)
            : "transparent"
    }

    Item {
        id: contentRow
        anchors { left: parent.left; leftMargin: Theme.margin; right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
        height: parent.height

        Item {
            id: vizArea
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 30
            height: parent.height

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
            anchors { left: vizArea.right; leftMargin: Theme.margin; right: parent.right; verticalCenter: parent.verticalCenter }
            height: parent.height
            clip: true

            Row {
                id: scrollRow
                anchors.verticalCenter: parent.verticalCenter
                x: 0

                Text {
                    id: t1
                    text: root.displayText !== "" ? root.displayText : "--------"
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    color: Colors.foreground
                }
                Text {
                    id: sep
                    text: root.displayText !== "" ? " " : ""
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    color: Colors.foreground
                }
                Text {
                    text: root.displayText !== "" ? root.displayText : ""
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    color: Colors.foreground
                }
            }

            NumberAnimation {
                id: scrollAnim
                target: scrollRow
                property: "x"
                from: 0
                to: -(t1.implicitWidth + sep.implicitWidth)
                duration: (t1.implicitWidth + sep.implicitWidth) * Theme.marqueeSpeed
                loops: Animation.Infinite
                running: false
                easing.type: Easing.Linear
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle(Panels.media)
    }
}
