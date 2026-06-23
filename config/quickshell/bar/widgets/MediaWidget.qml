import "../../theme"
import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

Item {
    id: root
    width: 30 + 10 + textMetrics.width + 20
    height: 30
    clip: true
    visible: true

    property var currentPlayer: null
    property string trackTitle: ""
    property string trackArtist: ""
    property int playbackState: MprisPlaybackState.Stopped
    property var playerTimestamps: ({})

    property int maxChars: 8

    property string displayText: ""
    property string scrollText: ""

    property int scrollPos: 0

    property var peakNode: null
    property var peakLevels: [0, 0, 0, 0, 0, 0, 0, 0]
    property int peakFps: 20
    function updateDisplayText() {
        displayText = trackArtist ? trackArtist + " - " + trackTitle : trackTitle
        scrollText = displayText + " " + displayText
    }

    TextMetrics {
        id: textMetrics
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        text: "M".repeat(maxChars)
    }

    function refreshPeakNode() {
        var nodes = Pipewire.nodes
        if (!nodes || !nodes.values) return
        var vals = nodes.values
        for (var i = 0; i < vals.length; i++) {
            var n = vals[i]
            if (n.audio && !n.isStream && n.isSink) {
                peakNode = n
                return
            }
        }
    }

    function refreshPlayer() {
        var raw = Mpris.players.values
        var now = Date.now()
        var activeKeys = {}

        for (var i = 0; i < raw.length; i++) {
            var p = raw[i]
            var key = p.desktopEntry || p.identity || p.dbusName
            activeKeys[key] = true
            var prev = playerTimestamps[key]
            if (!prev) {
                playerTimestamps[key] = { trackTitle: p.trackTitle, playbackState: p.playbackState, time: now }
            } else if (prev.trackTitle !== p.trackTitle || prev.playbackState !== p.playbackState) {
                prev.trackTitle = p.trackTitle
                prev.playbackState = p.playbackState
                prev.time = now
            }
        }

        for (var key in playerTimestamps) {
            if (!activeKeys[key]) delete playerTimestamps[key]
        }

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

        var playingPlayers = []
        for (var i = 0; i < filtered.length; i++) {
            if (filtered[i].playbackState === MprisPlaybackState.Playing) {
                playingPlayers.push(filtered[i])
            }
        }

        var playing = null
        if (playingPlayers.length === 1) {
            playing = playingPlayers[0]
        } else if (playingPlayers.length > 1) {
            var bestPlaying = playingPlayers[0]
            var bestTime = 0
            for (var i = 0; i < playingPlayers.length; i++) {
                var key = playingPlayers[i].desktopEntry || playingPlayers[i].identity || playingPlayers[i].dbusName
                var ts = playerTimestamps[key] ? playerTimestamps[key].time : 0
                if (ts > bestTime) {
                    bestTime = ts
                    bestPlaying = playingPlayers[i]
                }
            }
            playing = bestPlaying
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
        id: peakNodeRefresh
        interval: 500
        repeat: false
        running: false
        onTriggered: refreshPeakNode()
    }

    Connections {
        target: Pipewire?.nodes
        function onValuesChanged() {
            if (!peakNode) { refreshPeakNode(); return }
            var vals = Pipewire.nodes.values
            var found = false
            for (var i = 0; i < vals.length; i++) {
                if (vals[i] === peakNode) { found = true; break }
            }
            if (!found) peakNodeRefresh.restart()
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: refreshPlayer()
    }

    PwNodePeakMonitor {
        id: peakMon
        node: peakNode
        enabled: root.visible
    }

    Timer {
        interval: 1000 / Math.max(1, peakFps)
        running: root.visible
        repeat: true
        onTriggered: {
            var arr = root.peakLevels.slice()
            if (peakNode) {
                var raw = Math.min(1, peakMon.peak)
                for (var i = 0; i < 8; i++) {
                    var sensitivity = 0.3 + Math.random() * 1.2
                    var decay = 0.01 + Math.random() * 0.05
                    var target = Math.min(1, raw * sensitivity * 1.2)
                    if (target > arr[i]) {
                        arr[i] = target
                    } else if (arr[i] > 0) {
                        arr[i] = Math.max(0, arr[i] - decay)
                    }
                }
            } else {
                for (var i = 0; i < 8; i++) arr[i] = 0
            }
            root.peakLevels = arr
        }
    }

    Component.onCompleted: { refreshPlayer(); refreshPeakNode(); startScroll() }

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
                model: 8

                delegate: Item {
                    property int colIdx: index
                    x: colIdx * 4
                    width: 2
                    height: parent.height

                    Repeater {
                        model: 8

                        delegate: Rectangle {
                            required property int index
                            width: 2
                            height: 2
                            y: parent.height - 2 - index * 4
                            color: Colors.foreground
                            opacity: index === 0 ? 1.0 : (index < Math.round(root.peakLevels[colIdx] * 8) ? 1.0 : 0.0)
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
                font.pixelSize: 16
                font.family: "JetBrainsMono Nerd Font"
                color: Colors.foreground
            }
        }
    }

    function startScroll() {
        if (playbackState !== MprisPlaybackState.Playing) return
        if (Array.from(root.displayText).length <= root.maxChars) return
        var ms = Date.now() % 250
        var delay = ms === 0 ? 0 : 250 - ms
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

    onDisplayTextChanged: { scrollPos = 0; startScroll() }

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
