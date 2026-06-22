import "../../theme"
import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root
    width: textMetrics.width + 20
    height: 30
    clip: true
    visible: true

    property var currentPlayer: null
    property string trackTitle: ""
    property string trackArtist: ""
    property int playbackState: MprisPlaybackState.Stopped
    property var allPlayers: []

    property int maxChars: 8

    property string displayText: ""
    property string scrollText: ""
    property int scrollPos: 0

    function updateDisplayText() {
        displayText = trackArtist ? trackArtist + " - " + trackTitle : trackTitle
        scrollText = displayText + " " + displayText
    }

    TextMetrics {
        id: textMetrics
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        text: "\u266b MMMMMMMM"
    }

    function refreshPlayer() {
        var raw = Mpris.players.values
        var best = {}
        for (var i = 0; i < raw.length; i++) {
            var p = raw[i]
            var key = p.desktopEntry || p.identity || p.dbusName
            if (best[key] === undefined) {
                best[key] = p
            } else {
                var cur = best[key]
                var curScore = (cur.playbackState === MprisPlaybackState.Playing ? 2 : 0) + (cur.trackTitle ? 1 : 0)
                var newScore = (p.playbackState === MprisPlaybackState.Playing ? 2 : 0) + (p.trackTitle ? 1 : 0)
                if (newScore > curScore) best[key] = p
            }
        }
        var filtered = []
        for (var key in best) filtered.push(best[key])
        allPlayers = filtered
        var playing = null
        for (var i = 0; i < filtered.length; i++) {
            if (filtered[i].playbackState === MprisPlaybackState.Playing) {
                playing = filtered[i]
                break
            }
        }
        if (!playing && currentPlayer) return

        if (playing !== currentPlayer) {
            currentPlayer = playing
            if (playing) {
                trackTitle = playing.trackTitle || ""
                trackArtist = playing.trackArtist || ""
                playbackState = playing.playbackState
                updateDisplayText()
            } else {
                trackTitle = ""
                trackArtist = ""
                playbackState = MprisPlaybackState.Stopped
                displayText = ""
                scrollText = ""
            }
            scrollPos = 0
        }
    }

    Connections {
        target: currentPlayer
        function onTrackTitleChanged() { trackTitle = currentPlayer?.trackTitle ?? ""; playbackState = currentPlayer?.playbackState ?? MprisPlaybackState.Stopped; trackArtist = currentPlayer?.trackArtist ?? ""; updateDisplayText() }
        function onTrackArtistChanged() { trackArtist = currentPlayer?.trackArtist ?? ""; updateDisplayText() }
        function onPlaybackStateChanged() {
            playbackState = currentPlayer?.playbackState ?? MprisPlaybackState.Stopped
            if (playbackState === MprisPlaybackState.Playing) {
                startScroll()
            } else {
                scrollPos = 0
                scrollTimer.running = false
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: refreshPlayer()
    }

    Component.onCompleted: { refreshPlayer(); startScroll() }

    Rectangle {
        x: contentRow.x - 10
        y: 0
        width: contentRow.width + 20
        height: 30
        color: mouseArea.containsMouse ? Colors.background : "transparent"
    }

    Item {
        id: contentRow
        anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        height: parent.height

        Text {
            id: iconText
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "\u266b"
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
            color: Colors.foreground
        }

        Item {
            id: clipArea
            anchors { left: iconText.right; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
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
                font.pixelSize: 16
                font.family: "JetBrainsMono Nerd Font"
                color: Colors.foreground
            }
        }
    }

    function startScroll() {
        if (playbackState !== MprisPlaybackState.Playing) return
        if (Array.from(root.displayText).length <= root.maxChars) return
        var ms = Date.now() % 1000
        var delay = ms < 250 ? 250 - ms : 1250 - ms
        scrollTimer.interval = delay
        scrollTimer.repeat = false
        scrollTimer.running = true
    }

    Timer {
        id: scrollTimer
        interval: 500
        repeat: false
        running: false

        onTriggered: {
            if (!scrollTimer.repeat) {
                scrollTimer.interval = 250
                scrollTimer.repeat = true
                scrollTimer.running = true
            }
            var clen = Array.from(root.displayText).length
            if (root.scrollPos >= clen) {
                root.scrollPos = 0
            } else {
                root.scrollPos++
            }
        }
    }

    onDisplayTextChanged: { scrollText = displayText + "" + displayText; scrollPos = 0; scrollTimer.running = false; startScroll() }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ipcToggle.running = true
    }

    Process {
        id: ipcToggle
        command: ["qs", "ipc", "call", "overlay", "toggle", "media"]
        running: false
    }
}
