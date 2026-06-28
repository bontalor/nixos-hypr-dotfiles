pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Shared Mpris state and selection logic for the bar MediaWidget and the
// MediaPanel. Previously duplicated nearly verbatim across both files.
//
// Exposes:
//   - refreshCounter        bumps whenever any player's playbackState or
//                           trackTitle changes; bind `void` against it in
//                           `currentPlayer`/`trackTitle` properties to force
//                           a re-evaluation (Mpris doesn't emit notify on
//                           reassigning the same QObject).
//   - playerTimestamps      keyed by desktopEntry||identity||dbusName,
//                           recording the last time a player's track /
//                           playback state changed (used to break ties
//                           when multiple players are simultaneously
//                           Playing).
//   - allPlayers()          deduplicated, preferring the playing+has-title
//                           instance when a key collides. Returns Mpris
//                           players keyed by stable identity.
//   - selectCurrent(players)  preferred player from a list — currently
//                           Playing wins; ties broken by most-recent
//                           timestamp; falling back to first available.
//   - updateTimestamp(p)    record a transition for player `p`.

Singleton {
    id: root

    property int refreshCounter: 0
    property var playerTimestamps: ({})

    function _key(p) {
        return p ? (p.desktopEntry || p.identity || p.dbusName) : ""
    }

    function allPlayers() {
        var raw = Mpris.players.values
        var best = {}
        for (var i = 0; i < raw.length; i++) {
            var p = raw[i]
            var key = root._key(p)
            if (best[key] === undefined) {
                best[key] = p
            } else {
                var cur = best[key]
                var curScore = (cur.playbackState === MprisPlaybackState.Playing ? 2 : 0)
                             + (cur.trackTitle ? 1 : 0)
                var newScore = (p.playbackState === MprisPlaybackState.Playing ? 2 : 0)
                             + (p.trackTitle ? 1 : 0)
                if (newScore > curScore) best[key] = p
            }
        }
        var out = []
        for (var k in best) out.push(best[k])
        return out
    }

    function selectCurrent(players) {
        if (!players || players.length === 0) return null
        var playing = []
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) playing.push(players[i])
        }
        if (playing.length === 1) return playing[0]
        if (playing.length > 1) {
            var bestPlaying = playing[0]
            var bestTime = 0
            for (var j = 0; j < playing.length; j++) {
                var key = root._key(playing[j])
                var ts = root.playerTimestamps[key] ? root.playerTimestamps[key].time : 0
                if (ts > bestTime) {
                    bestTime = ts
                    bestPlaying = playing[j]
                }
            }
            return bestPlaying
        }
        return players[0]
    }

    function updateTimestamp(p) {
        if (!p) return
        var key = root._key(p)
        var now = Date.now()
        var prev = root.playerTimestamps[key]
        if (!prev) {
            root.playerTimestamps[key] = { trackTitle: p.trackTitle, playbackState: p.playbackState, time: now }
        } else if (prev.trackTitle !== p.trackTitle || prev.playbackState !== p.playbackState) {
            prev.trackTitle = p.trackTitle
            prev.playbackState = p.playbackState
            prev.time = now
        }
    }

    Instantiator {
        model: Mpris.players
        delegate: Connections {
            target: modelData
            function onPlaybackStateChanged() { root.updateTimestamp(modelData); root.refreshCounter++ }
            function onTrackTitleChanged()    { root.updateTimestamp(modelData); root.refreshCounter++ }
        }
    }
}