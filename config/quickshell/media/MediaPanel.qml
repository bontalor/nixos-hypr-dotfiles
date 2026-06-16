import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

FloatingWindow {
    id: root
    title: "Media"
    color: "transparent"
    implicitWidth: 520
    implicitHeight: 520
    visible: false

    onClosed: visible = false

    property int selSection: 0
    property bool inSection: false
    property int selDevice: 0

    property var allPlayers: []
    property var currentPlayer: null
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property int playbackState: MprisPlaybackState.Stopped
    property string playerName: ""
    property real trackPosition: currentPlayer ? currentPlayer.position : 0
    property real trackLength: currentPlayer ? currentPlayer.length : 0
    property bool canSeek: currentPlayer ? currentPlayer.canSeek : false
    property string trackArtUrl: currentPlayer ? (currentPlayer.trackArtUrl || "") : ""
    property bool manuallySelected: false

    function fmtTime(sec) {
        var totalSec = Math.floor(sec)
        var m = Math.floor(totalSec / 60)
        var s = totalSec % 60
        return (" " + m).slice(-2) + ":" + ("0" + s).slice(-2)
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
        if (manuallySelected) {
            if (currentPlayer && filtered.indexOf(currentPlayer) >= 0) return
            manuallySelected = false
        }
        var playing = null
        for (var i = 0; i < filtered.length; i++) {
            if (filtered[i].playbackState === MprisPlaybackState.Playing) {
                playing = filtered[i]
                break
            }
        }
        if (!playing && currentPlayer) return
        setPlayer(playing)
    }

    Process {
        id: ipcRefresh
        command: ["qs", "ipc", "call", "refresh-media", "refresh"]
        running: false
    }

    function setPlayer(player) {
        currentPlayer = player
        if (player) {
            trackTitle = player.trackTitle ?? ""
            trackArtist = player.trackArtist ?? ""
            trackAlbum = player.trackAlbum ?? ""
            playbackState = player.playbackState
            playerName = player.identity ?? ""
        } else {
            trackTitle = ""; trackArtist = ""; trackAlbum = ""
            playbackState = MprisPlaybackState.Stopped; playerName = ""
        }
        ipcRefresh.running = true
    }

    Connections {
        target: currentPlayer
        function onTrackTitleChanged() { trackTitle = currentPlayer?.trackTitle ?? ""; ipcRefresh.running = true }
        function onTrackArtistChanged() { trackArtist = currentPlayer?.trackArtist ?? ""; ipcRefresh.running = true }
        function onTrackAlbumChanged() { trackAlbum = currentPlayer?.trackAlbum ?? ""; ipcRefresh.running = true }
        function onPlaybackStateChanged() { playbackState = currentPlayer?.playbackState ?? MprisPlaybackState.Stopped; ipcRefresh.running = true }
    }

    Timer {
        id: posTimer
        interval: 1000; repeat: true; running: currentPlayer !== null && playbackState === MprisPlaybackState.Playing
        onTriggered: { if (currentPlayer) currentPlayer.positionChanged() }
    }

    Timer {
        interval: 2000; repeat: true; running: true
        onTriggered: refreshPlayer()
    }

    onVisibleChanged: {
        if (visible) {
            manuallySelected = false
            refreshPlayer()
            mainRect.forceActiveFocus()
            selSection = 0
            inSection = false
            selDevice = 0
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }

    Rectangle {
        id: mainRect
        anchors.fill: parent
        color: "transparent"
        focus: true

        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_Tab:
                if (event.modifiers & Qt.ShiftModifier) {
                    if (inSection) {
                        inSection = false
                    } else {
                        selSection = Math.max(selSection - 1, 0)
                    }
                } else if (inSection) {
                    var maxD = allPlayers.length - 1
                    selDevice = Math.min(selDevice + 1, Math.max(0, maxD))
                } else {
                    inSection = true
                    selDevice = 0
                }
                event.accepted = true; break
            case Qt.Key_Backtab:
                if (inSection) {
                    inSection = false
                }
                event.accepted = true; break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (inSection && selDevice < allPlayers.length) {
                    setPlayer(allPlayers[selDevice])
                } else if (!inSection) {
                    inSection = true
                    selDevice = 0
                }
                event.accepted = true; break
            case Qt.Key_J:
            case Qt.Key_Down:
                if (inSection) {
                    var maxD = allPlayers.length - 1
                    selDevice = Math.min(selDevice + 1, Math.max(0, maxD))
                } else {
                    selSection = Math.min(selSection + 1, allPlayers.length - 1)
                }
                event.accepted = true; break
            case Qt.Key_K:
            case Qt.Key_Up:
                if (inSection) {
                    selDevice = Math.max(selDevice - 1, 0)
                } else {
                    selSection = Math.max(selSection - 1, 0)
                }
                event.accepted = true; break
            case Qt.Key_Escape:
                event.accepted = true; break
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                width: (parent.width - parent.spacing) * 0.25
                height: parent.height
                color: Qt.alpha(Colors.base00, 0.75)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        width: parent.width
                        height: 30
                        color: Qt.alpha(Colors.base0d, 0.75)

                        Text {
                            text: "Sources"
                            anchors {
                                left: parent.left; leftMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            color: Colors.foreground
                            font.pixelSize: 16
                            font.family: "JetBrainsMono Nerd Font"
                            font.bold: true
                        }
                    }

                    Repeater {
                        model: allPlayers.length

                        delegate: Rectangle {
                            width: parent.width
                            height: 30
                            color: allPlayers[index] === root.currentPlayer
                                   ? Qt.alpha(Colors.base01, 0.75)
                                   : "transparent"

                            Text {
                                text: allPlayers[index] ? (allPlayers[index].identity || "Unknown") : ""
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    right: parent.right; rightMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                elide: Text.ElideRight
                                leftPadding: selSection === index && inSection ? 18 : 0
                            }

                            Text {
                                text: "\u25b6"
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                visible: selSection === index && inSection
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    selSection = index
                                    inSection = false
                                    manuallySelected = true
                                    setPlayer(allPlayers[index])
                                    mainRect.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: (parent.width - parent.spacing) * 0.75
                height: parent.height
                color: Qt.alpha(Colors.base00, 0.75)

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 10
                    contentHeight: contentCol.height
                    clip: true

                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            width: parent.width
                            height: 30
                            color: Qt.alpha(Colors.base0d, 0.75)

                            Text {
                                text: currentPlayer ? (currentPlayer.identity ?? "Now Playing") : "No Source Selected"
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                font.bold: true
                            }
                        }

                        Text {
                            width: parent.width
                            text: root.trackTitle || "No Track"
                            color: Colors.foreground
                            font.pixelSize: 16
                            font.family: "JetBrainsMono Nerd Font"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            visible: currentPlayer !== null
                        }

                        Text {
                            width: parent.width
                            text: root.trackArtist || ""
                            color: Colors.foreground
                            font.pixelSize: 16
                            font.family: "JetBrainsMono Nerd Font"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            visible: currentPlayer !== null && text !== ""
                        }

                        Item {
                            width: parent.width
                            height: 220
                            visible: currentPlayer !== null && root.trackArtUrl !== ""

                            Image {
                                anchors.centerIn: parent
                                width: 220; height: 220
                                source: root.trackArtUrl
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No media playing"
                            color: Qt.alpha(Colors.foreground, 0.75)
                            font.pixelSize: 16
                            font.family: "JetBrainsMono Nerd Font"
                            visible: currentPlayer === null
                        }

                        Item {
                            width: parent.width
                            height: 8
                            visible: currentPlayer !== null && trackLength > 0

                            Text {
                                id: elapsedText
                                text: fmtTime(root.trackPosition)
                                color: Qt.alpha(Colors.foreground, 0.75)
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                width: 47
                                horizontalAlignment: Text.AlignRight
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            }

                            Rectangle {
                                anchors { left: elapsedText.right; leftMargin: 9; right: remainingText.left; rightMargin: 9; verticalCenter: parent.verticalCenter }
                                height: 10
                                color: Qt.alpha(Colors.foreground, 0.75)

                                Rectangle {
                                    height: parent.height
                                    width: parent.width * (Math.min(1, root.trackPosition / Math.max(1, root.trackLength)))
                                    color: Colors.foreground
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: root.canSeek
                                    onClicked: {
                                        if (currentPlayer && root.canSeek) {
                                            var ratio = mouse.x / width
                                            var targetPos = ratio * root.trackLength
                                            currentPlayer.seek(targetPos - currentPlayer.position)
                                        }
                                    }
                                }
                            }

                            Text {
                                id: remainingText
                                text: fmtTime(root.trackLength)
                                color: Qt.alpha(Colors.foreground, 0.75)
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                width: 47
                                horizontalAlignment: Text.AlignLeft
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 45
                            visible: currentPlayer !== null
                            spacing: 10

                            Rectangle {
                                width: 45; height: 45
                                color: Qt.alpha(Colors.base0d, 0.75)

                                Item {
                                    anchors.centerIn: parent
                                    width: 30; height: 30

                                    Text {
                                        anchors.fill: parent
                                        text: "\u23ee"
                                        color: Colors.foreground
                                        font.pixelSize: 30
                                        font.family: "JetBrainsMono Nerd Font"
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (currentPlayer && currentPlayer.canGoPrevious) currentPlayer.previous() }
                                }
                            }

                            Rectangle {
                                width: 45; height: 45
                                color: Qt.alpha(Colors.base0d, 0.75)

                                Item {
                                    anchors.centerIn: parent
                                    width: 30; height: 30

                                    Text {
                                        anchors.fill: parent
                                        text: root.playbackState === MprisPlaybackState.Playing ? "\u23f8" : "\u23f5"
                                        color: Colors.foreground
                                        font.pixelSize: 30
                                        font.family: "JetBrainsMono Nerd Font"
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (currentPlayer) currentPlayer.togglePlaying() }
                                }
                            }

                            Rectangle {
                                width: 45; height: 45
                                color: Qt.alpha(Colors.base0d, 0.75)

                                Item {
                                    anchors.centerIn: parent
                                    width: 30; height: 30

                                    Text {
                                        anchors.fill: parent
                                        text: "\u23ed"
                                        color: Colors.foreground
                                        font.pixelSize: 30
                                        font.family: "JetBrainsMono Nerd Font"
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (currentPlayer && currentPlayer.canGoNext) currentPlayer.next() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
