import "../theme"
import "../components"
import "../util"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Media panel — now-playing UI for MPRIS players.
//
// Extends the shared Panel scaffold (previously duplicated the sidebar,
// keyboard nav, Escape shortcut, visibility reset, and ▶ selection marker
// from Panel.qml). The sidebar lists players; the content area shows the
// selected player's track info, album art, seek bar, and transport buttons.

Panel {
    id: root
    title: "Media"
    useDefaultKeys: false
    autoScroll: false

    // Sidebar = player list. Panel's `sections` drives the sidebar Repeater.
    sidebarHeader: "Sources"
    sections: {
        var players = root.allPlayers
        var out = []
        for (var i = 0; i < players.length; i++) {
            out.push({ name: players[i].identity || "Unknown" })
        }
        return out
    }

    // The content area shows whichever player is selected in the sidebar
    // (selSection). On open, selSection is set to the currently-playing
    // player so the user sees what's active immediately.
    property var currentPlayer: {
        if (root.selSection >= 0 && root.selSection < root.allPlayers.length)
            return root.allPlayers[root.selSection]
        return null
    }

    property var allPlayers: MprisSelector.allPlayers()

    property string trackTitle: currentPlayer?.trackTitle ?? ""
    property string trackArtist: currentPlayer?.trackArtist ?? ""
    property string trackAlbum: currentPlayer?.trackAlbum ?? ""
    property int playbackState: currentPlayer?.playbackState ?? MprisPlaybackState.Stopped
    property string playerName: currentPlayer?.identity ?? ""
    property real trackLength: currentPlayer?.length ?? 0
    property bool canSeek: currentPlayer?.canSeek ?? false
    property string trackArtUrl: currentPlayer?.trackArtUrl ?? ""

    // Quickshell's Mpris service interpolates `position` using wall-clock
    // time in C++ (positionMs = lastDbusPosition + elapsed*rate), so
    // reading `currentPlayer.position` always returns the exact current
    // position — but `positionChanged` only fires on real DBus events
    // (seeks). The Timer below re-emits it every second so the binding
    // re-reads the interpolated value, keeping the progress bar synced.
    property real trackPosition: currentPlayer?.position ?? 0

    function fmtTime(sec) { return FormatUtil.fmtSeconds(sec) }

    onShown: {
        // Open on the currently-playing player so the user sees what's
        // active immediately, rather than always landing on index 0.
        var idx = root.allPlayers.indexOf(MprisSelector.currentPlayer)
        selSection = idx >= 0 ? idx : 0
    }

    // Re-emit `positionChanged` every second so the `trackPosition` binding
    // re-reads the wall-clock-interpolated value from Quickshell's C++
    // MprisPlayer. The signal only fires on real DBus events (seeks)
    // otherwise, so without this nudge the binding goes stale between
    // events.
    Timer {
        interval: 1000
        running: root.visible && root.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: if (root.currentPlayer) root.currentPlayer.positionChanged()
    }

    onKeyPressed: function(event) {
        switch (event.key) {
        case Qt.Key_Tab:
            if (event.modifiers & Qt.ShiftModifier) {
                root.selSection = Scroll.clamp(root.selSection - 1, 0, root.allPlayers.length - 1)
            } else {
                root.selSection = Scroll.clamp(root.selSection + 1, 0, root.allPlayers.length - 1)
            }
            event.accepted = true; break
        case Qt.Key_Backtab:
            root.selSection = Scroll.clamp(root.selSection - 1, 0, root.allPlayers.length - 1)
            event.accepted = true; break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            // No-op — currentPlayer already follows selSection. Enter is
            // consumed so Panel's base handler doesn't fire.
            event.accepted = true; break
        case Qt.Key_J:
        case Qt.Key_Down:
            root.selSection = Scroll.clamp(root.selSection + 1, 0, root.allPlayers.length - 1)
            event.accepted = true; break
        case Qt.Key_K:
        case Qt.Key_Up:
            root.selSection = Scroll.clamp(root.selSection - 1, 0, root.allPlayers.length - 1)
            event.accepted = true; break
        case Qt.Key_H:
        case Qt.Key_Left:
            if (root.canSeek && root.currentPlayer) root.currentPlayer.seek(-5)
            event.accepted = true; break
        case Qt.Key_L:
        case Qt.Key_Right:
            if (root.canSeek && root.currentPlayer) root.currentPlayer.seek(5)
            event.accepted = true; break
        case Qt.Key_Space:
            if (root.currentPlayer) root.currentPlayer.togglePlaying()
            event.accepted = true; break
        }
    }

    // Override the sidebar delegate to show player selection state.
    // Panel's default sidebar shows section names + ▶ marker; we keep
    // that but also highlight the currently-playing player.

    // ---- Content: Now-playing UI ----
    // The default slot lands in Panel's contentCol (inside the Flickable,
    // below the section header bar). We use a single Item sized to the
    // available content height so the Flickable doesn't scroll. All
    // content (including the empty state) goes inside this Item so we
    // can use anchors freely (Column doesn't allow anchored children).
    Item {
        width: parent.width
        height: root.flick ? root.flick.height - root.headerHeight - root.colSpacing : 0

        // Now-playing UI
        Item {
            id: nowPlaying
            anchors.fill: parent
            visible: root.currentPlayer !== null

        Column {
            id: topContent
            anchors { top: parent.top; left: parent.left; right: parent.right }
            spacing: Theme.margin

            ThemeText {
                width: parent.width
                text: root.trackTitle || "No Track"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            ThemeText {
                width: parent.width
                text: root.trackArtist || ""
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: text !== ""
            }
        }

        Item {
            id: artArea
            anchors {
                left: parent.left; right: parent.right
                top: topContent.bottom; bottom: bottomCol.top
            }
            visible: root.trackArtUrl !== ""

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

        Column {
            id: bottomCol
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            spacing: Theme.margin

            // Seek bar
            Item {
                width: parent.width
                height: 8
                visible: root.trackLength > 0

                ThemeText {
                    id: elapsedText
                    text: root.fmtTime(root.trackPosition)
                    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                    width: 47
                    horizontalAlignment: Text.AlignRight
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                }

                Rectangle {
                    anchors { left: elapsedText.right; leftMargin: 9; right: remainingText.left; rightMargin: 9; verticalCenter: parent.verticalCenter }
                    height: 10
                    color: Qt.alpha(Colors.foreground, Theme.alphaInactive)

                    Rectangle {
                        height: parent.height
                        width: parent.width * (Math.min(1, root.trackPosition / Math.max(1, root.trackLength)))
                        color: Colors.foreground
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.canSeek
                        onClicked: (mouse) => {
                            if (root.currentPlayer && root.canSeek) {
                                var ratio = mouse.x / width
                                var targetPos = ratio * root.trackLength
                                root.currentPlayer.seek(targetPos - root.currentPlayer.position)
                            }
                        }
                    }
                }

                ThemeText {
                    id: remainingText
                    text: root.fmtTime(root.trackLength)
                    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                    width: 47
                    horizontalAlignment: Text.AlignLeft
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                }
            }

            // Transport buttons — Nerd Font glyphs (previously hand-drawn
            // via Canvas with raw pixel coordinates).
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 45
                spacing: Theme.margin

                Rectangle {
                    width: 45; height: 45
                    color: prevBtn.containsMouse ? Qt.alpha(Colors.accent, Theme.alphaSectionHeader + Theme.alphaHover) : Qt.alpha(Colors.accent, Theme.alphaSectionHeader)
                    ThemeText {
                        anchors.centerIn: parent
                        text: Icon.prev
                        font.pixelSize: Theme.fontPixelSizeXLarge
                    }
                    MouseArea {
                        id: prevBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.currentPlayer && root.currentPlayer.canGoPrevious) root.currentPlayer.previous() }
                    }
                }

                Rectangle {
                    width: 45; height: 45
                    color: playBtn.containsMouse ? Qt.alpha(Colors.accent, Theme.alphaSectionHeader + Theme.alphaHover) : Qt.alpha(Colors.accent, Theme.alphaSectionHeader)
                    ThemeText {
                        anchors.centerIn: parent
                        text: root.playbackState === MprisPlaybackState.Playing ? Icon.pause : Icon.play
                        font.pixelSize: Theme.fontPixelSizeXLarge
                    }
                    MouseArea {
                        id: playBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.currentPlayer) root.currentPlayer.togglePlaying() }
                    }
                }

                Rectangle {
                    width: 45; height: 45
                    color: nextBtn.containsMouse ? Qt.alpha(Colors.accent, Theme.alphaSectionHeader + Theme.alphaHover) : Qt.alpha(Colors.accent, Theme.alphaSectionHeader)
                    ThemeText {
                        anchors.centerIn: parent
                        text: Icon.next
                        font.pixelSize: Theme.fontPixelSizeXLarge
                    }
                    MouseArea {
                        id: nextBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.currentPlayer && root.currentPlayer.canGoNext) root.currentPlayer.next() }
                    }
                }
            }
        }
        }

        // Empty state when no player is active.
        ThemeText {
            anchors.centerIn: parent
            text: "No media playing"
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            visible: root.currentPlayer === null
        }
    }
}
