pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Shared Mpris state and selection logic for the bar MediaWidget and the
// MediaPanel. Previously duplicated nearly verbatim across both files.
//
// Exposes:
//   - currentPlayer         readonly binding — the preferred player from
//                           the current Mpris.players list. Re-evaluates
//                           automatically when any player's playbackState
//                           or trackTitle changes (no refreshCounter hack).
//   - playersChanged()      signal emitted on player add/remove/state
//                           change for consumers that need a side effect
//                           beyond a property binding.
//   - allPlayers()          deduplicated, preferring the playing+has-title
//                           instance when a key collides.
//   - selectCurrent(players)  preferred player from a list — currently
//                           Playing wins; ties broken by most-recent
//                           timestamp; falling back to first available.
//   - updateTimestamp(p)    record a transition for player `p`.

Singleton {
    id: root

    signal playersChanged()

    // Keyed by desktopEntry||identity||dbusName. Pruned when a player
    // disappears (see Instantiator delegate's onDestruction).
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
                // Playing wins; has-title breaks the next tie.
                var curScore = (cur.playbackState === MprisPlaybackState.Playing ? 2 : 0)
                             + (cur.trackTitle ? 1 : 0)
                var newScore = (p.playbackState === MprisPlaybackState.Playing ? 2 : 0)
                             + (p.trackTitle ? 1 : 0)
                if (newScore > curScore) best[key] = p
            }
        }
        return Object.keys(best).map(function(k) { return best[k] })
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

    // The preferred player. A plain readonly binding reads
    // `Mpris.players` plus each candidate's `playbackState`/`trackTitle`
    // during evaluation, so QML re-evaluates this automatically when any
    // of those change — no refreshCounter / `void` hack required.
    readonly property var currentPlayer: root.selectCurrent(root.allPlayers())

    // Single shared peak monitor, enabled only while something is playing.
    // Gating on playback state prevents PipeWire from scheduling the node
    // when it's idle, which eliminates xruns at rest.
    PwNodePeakMonitor {
        id: sinkPeakMon
        node: Pipewire.defaultAudioSink
        enabled: root.currentPlayer?.playbackState === MprisPlaybackState.Playing
    }

    readonly property real sinkPeak: sinkPeakMon.peak

    Instantiator {
        model: Mpris.players
        delegate: Connections {
            target: modelData
            function onPlaybackStateChanged() { root.updateTimestamp(modelData); root.playersChanged() }
            function onTrackTitleChanged()    { root.updateTimestamp(modelData); root.playersChanged() }
            // Prune the timestamp entry when this player disappears from
            // the Mpris list — prevents unbounded growth as players churn.
            Component.onDestruction: {
                var key = root._key(modelData)
                if (root.playerTimestamps[key] !== undefined) {
                    delete root.playerTimestamps[key]
                    root.playersChanged()
                }
            }
        }
    }
}
