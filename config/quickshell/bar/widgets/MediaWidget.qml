import "../../theme"
import "../../util"
import "../../media"
import QtQuick
import Quickshell.Services.Mpris

WidgetButton {
    id: root
    width: root.vizWidth + Theme.margin + textMetrics.width + 2 * Theme.margin
    clip: true
    panel: Panels.media

    // Dot-matrix geometry: 2px dots on a 4px vertical stride, in a
    // fixed 60x30 area left of the marquee. Theme.peakBands columns
    // spread evenly across the width; rows fill the bar height.
    readonly property int dotStride: 4
    readonly property int vizWidth: 60
    readonly property int dotRows: Math.floor((Theme.barHeight - 2) / dotStride) + 1

    property var currentPlayer: MprisSelector.currentPlayer

    property string trackTitle: currentPlayer ? (currentPlayer.trackTitle ?? "") : ""
    property string trackArtist: currentPlayer ? (currentPlayer.trackArtist ?? "") : ""
    property int playbackState: currentPlayer ? currentPlayer.playbackState : MprisPlaybackState.Stopped

    property string displayText: currentPlayer
        ? (trackArtist ? trackArtist + " - " + trackTitle : trackTitle)
        : ""

    // Fixed marquee clip width — the widget shows at most ~8 characters
    // and scrolls longer titles through it.
    TextMetrics {
        id: textMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPixelSize
        text: "M".repeat(8)
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

    Item {
        id: contentRow
        anchors { left: parent.left; leftMargin: Theme.margin; right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
        height: parent.height

        // Real audio spectrum — one column per SpectrumModel band
        // (bass on the left), dots lit up to the band's level.
        Item {
            id: vizArea
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: root.vizWidth
            height: parent.height

            Repeater {
                model: Theme.peakBands
                delegate: Item {
                    property int colIdx: index
                    x: colIdx * (root.vizWidth - 2) / (Theme.peakBands - 1)
                    width: 2
                    height: parent.height

                    Repeater {
                        model: root.dotRows
                        delegate: Rectangle {
                            required property int index
                            width: 2
                            height: 2
                            y: parent.height - 2 - index * root.dotStride
                            color: Colors.foreground
                            opacity: index === 0 ? 1.0 : (index < Math.round(SpectrumModel.bands[colIdx] * root.dotRows) ? 1.0 : 0.0)
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

                ThemeText {
                    id: t1
                    text: root.displayText !== "" ? root.displayText : "--------"
                }
                ThemeText {
                    id: sep
                    text: root.displayText !== "" ? " " : ""
                }
                ThemeText {
                    text: root.displayText !== "" ? root.displayText : ""
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
}
