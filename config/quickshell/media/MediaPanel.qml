import "../theme"
import "../util"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

FloatingWindow {
    id: root
    title: "Media"
    color: "transparent"
    implicitWidth: 850
    implicitHeight: 450
    visible: false

    onClosed: visible = false

    property int selSection: 0
    property bool inSection: false
    property int selDevice: 0

    property bool manuallySelected: false
    property var manualPlayer: null

    property var currentPlayer: {
        void MprisSelector.refreshCounter
        if (root.manuallySelected && root.manualPlayer) return root.manualPlayer
        return MprisSelector.selectCurrent(MprisSelector.allPlayers())
    }

    property var allPlayers: {
        void MprisSelector.refreshCounter
        return MprisSelector.allPlayers()
    }

    property string trackTitle: currentPlayer?.trackTitle ?? ""
    property string trackArtist: currentPlayer?.trackArtist ?? ""
    property string trackAlbum: currentPlayer?.trackAlbum ?? ""
    property int playbackState: currentPlayer?.playbackState ?? MprisPlaybackState.Stopped
    property string playerName: currentPlayer?.identity ?? ""
    property real trackLength: currentPlayer?.length ?? 0
    property bool canSeek: currentPlayer?.canSeek ?? false
    property string trackArtUrl: currentPlayer?.trackArtUrl ?? ""

    // Quickshell's Mpris service already interpolates `position` using
    // wall-clock time in C++ (positionMs = lastDbusPosition + elapsed*rate),
    // so reading `currentPlayer.position` always returns the exact current
    // position — but the `positionChanged` signal only fires on real DBus
    // events (seeks). The FrameAnimation below re-emits it every frame so
    // the binding re-reads the interpolated value, keeping the progress
    // bar perfectly synced with no drift.
    property real trackPosition: currentPlayer?.position ?? 0

    function fmtTime(sec) {
        return Util.fmtSeconds(sec)
    }

    function setPlayer(player) {
        manualPlayer = player
        manuallySelected = true
    }

    onVisibleChanged: {
        if (visible) {
            manuallySelected = false
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

    // Re-emit `positionChanged` every second so the `trackPosition` binding
    // re-reads the wall-clock-interpolated value from Quickshell's C++
    // MprisPlayer. The signal only fires on real DBus events (seeks)
    // otherwise, so without this nudge the binding goes stale between
    // events. A 1s Timer matches the elapsed-time text granularity.
    Timer {
        interval: 1000
        running: root.visible && root.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: if (root.currentPlayer) root.currentPlayer.positionChanged()
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
                    manuallySelected = true
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
                color: Qt.alpha(Colors.base00, Theme.alphaBackground)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        width: parent.width
                        height: 30
                        color: Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)

                        Text {
                            text: "Sources"
                            anchors {
                                left: parent.left; leftMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            color: Colors.foreground
                            font.pixelSize: Theme.fontPixelSize
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                    }

                    Repeater {
                        model: allPlayers.length

                        delegate: Rectangle {
                            width: parent.width
                            height: 30
                            color: allPlayers[index] === root.currentPlayer
                                   ? Qt.alpha(Colors.base01, Theme.alphaSelected)
                                   : "transparent"

                            Text {
                                text: allPlayers[index] ? (allPlayers[index].identity || "Unknown") : ""
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    right: parent.right; rightMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: Theme.fontPixelSize
                                font.family: Theme.fontFamily
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
                                font.pixelSize: Theme.fontPixelSize
                                font.family: Theme.fontFamily
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
                color: Qt.alpha(Colors.base00, Theme.alphaBackground)

                Item {
                    anchors {
                        top: parent.top; topMargin: 10
                        left: parent.left; leftMargin: 10
                        right: parent.right; rightMargin: 10
                        bottom: parent.bottom; bottomMargin: 10
                    }

                    Column {
                        id: topContent
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                        }
                        spacing: 10

                        Rectangle {
                            width: parent.width
                            height: 30
                            color: Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)

                            Text {
                                text: currentPlayer ? (currentPlayer.identity ?? "Now Playing") : "No Source Selected"
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: Theme.fontPixelSize
                                font.family: Theme.fontFamily
                                font.bold: true
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: currentPlayer !== null

                            Text {
                                width: parent.width
                                text: root.trackTitle || "No Track"
                                color: Colors.foreground
                                font.pixelSize: Theme.fontPixelSize
                                font.family: Theme.fontFamily
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                width: parent.width
                                text: root.trackArtist || ""
                                color: Colors.foreground
                                font.pixelSize: Theme.fontPixelSize
                                font.family: Theme.fontFamily
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                visible: text !== ""
                            }
                        }
                    }

                    Item {
                        id: artArea
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: topContent.bottom
                            bottom: bottomCol.top
                        }
                        visible: currentPlayer !== null && root.trackArtUrl !== ""

                        Image {
                            anchors.centerIn: parent
                            width: Math.min(220, parent.width)
                            height: Math.min(220, parent.height)
                            source: root.trackArtUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 220
                            sourceSize.height: 220
                            smooth: true
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No media playing"
                        color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                        visible: currentPlayer === null
                    }

                    Column {
                        id: bottomCol
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                        spacing: 10

                        Item {
                            width: parent.width
                            height: 8
                            visible: currentPlayer !== null && trackLength > 0

                            Text {
                                id: elapsedText
                                text: fmtTime(root.trackPosition)
                                color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                                font.pixelSize: Theme.fontPixelSize
                                font.family: Theme.fontFamily
                                width: 47
                                horizontalAlignment: Text.AlignRight
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            }

                            Rectangle {
                                anchors { left: elapsedText.right; leftMargin: 9; right: remainingText.left; rightMargin: 9; verticalCenter: parent.verticalCenter }
                                height: 10
                                color: Qt.alpha(Colors.foreground, 0.25)

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
                                color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                                font.pixelSize: Theme.fontPixelSize
                                font.family: Theme.fontFamily
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
                                color: Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)

                                Canvas {
                                    id: prevBtnIcon
                                    width: 30; height: 30
                                    anchors.centerIn: parent
                                    property color iconColor: Colors.foreground

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        if (!ctx) return
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.fillStyle = iconColor
                                        ctx.beginPath()
                                        ctx.moveTo(5, 15)
                                        ctx.lineTo(13, 5)
                                        ctx.lineTo(13, 25)
                                        ctx.closePath()
                                        ctx.fill()
                                        ctx.beginPath()
                                        ctx.moveTo(15, 15)
                                        ctx.lineTo(23, 5)
                                        ctx.lineTo(23, 25)
                                        ctx.closePath()
                                        ctx.fill()
                                    }

                                    Connections {
                                        target: Colors
                                        function onForegroundChanged() { prevBtnIcon.requestPaint() }
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
                                color: Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)

                                Canvas {
                                    id: playPauseBtnIcon
                                    width: 30; height: 30
                                    anchors.centerIn: parent
                                    property color iconColor: Colors.foreground
                                    property bool isPlaying: root.playbackState === MprisPlaybackState.Playing

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        if (!ctx) return
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.fillStyle = iconColor
                                        if (isPlaying) {
                                            ctx.fillRect(9, 6, 5, 18)
                                            ctx.fillRect(16, 6, 5, 18)
                                        } else {
                                            ctx.beginPath()
                                            ctx.moveTo(23, 15)
                                            ctx.lineTo(11, 5)
                                            ctx.lineTo(11, 25)
                                            ctx.closePath()
                                            ctx.fill()
                                        }
                                    }

                                    onIsPlayingChanged: playPauseBtnIcon.requestPaint()

                                    Connections {
                                        target: Colors
                                        function onForegroundChanged() { playPauseBtnIcon.requestPaint() }
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
                                color: Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)

                                Canvas {
                                    id: nextBtnIcon
                                    width: 30; height: 30
                                    anchors.centerIn: parent
                                    property color iconColor: Colors.foreground

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        if (!ctx) return
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.fillStyle = iconColor
                                        ctx.beginPath()
                                        ctx.moveTo(15, 15)
                                        ctx.lineTo(7, 5)
                                        ctx.lineTo(7, 25)
                                        ctx.closePath()
                                        ctx.fill()
                                        ctx.beginPath()
                                        ctx.moveTo(25, 15)
                                        ctx.lineTo(17, 5)
                                        ctx.lineTo(17, 25)
                                        ctx.closePath()
                                        ctx.fill()
                                    }

                                    Connections {
                                        target: Colors
                                        function onForegroundChanged() { nextBtnIcon.requestPaint() }
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
