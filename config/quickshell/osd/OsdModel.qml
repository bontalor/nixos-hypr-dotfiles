pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../theme"
import "../util"

// On-screen-display state singleton for volume + brightness. Driven via
// the `osd` IpcHandler in shell.qml. Volume read/written in-process
// through Pipewire; brightness shells out to `brightnessctl` (Quickshell
// 0.3.0 ships no backlight service). Maintains activeKind/value/glyph
// and a hide timer (hideInterval) that OsdPopup mirrors.
//
// Brightness note: `value` holds the *display* fraction (volume|mic|
// brightness — whatever the last popup was about). `brightnessValue` is
// a dedicated cache of the latest known brightness fraction so the
// `brightnessDown` floor check can't be confused by an interleaved
// volume/mic popup. `brightSetProc` updates `brightnessValue` from every
// `brightnessctl` reply; `brightReadProc` is the silent prime at startup.

Singleton {
    id: root

    property int hideInterval: 3000
    property int brightnessStep: 5           // percent per key press
    // Floor so `brightnessDown` can never blank the panel by driving the
    // backlight to 0% (brightnessctl allows 0 by default, which on most
    // laptops turns the panel off entirely — a footgun if the user
    // instinctively mashes the down key).
    property int brightnessMin: 1
    // Volume fraction below which the "low" glyph is shown.
    property real volumeGlyphThreshold: 0.5

    property string activeKind: ""    // "volume" | "brightness"
    property real value: 0            // display fraction (depends on activeKind)
    property string glyph: ""
    property bool visible: false

    // Separate brightness cache (0..1) so volume/mic popups can't pollute
    // the floor check on `brightnessDown`. Always set from the
    // `brightnessctl` reply in onBrightness; used by `brightnessDown`.
    property real brightnessValue: 0

    // Pipewire volume state. `?? 0`/`?? false` guards against
    // defaultAudioSink being null at startup.
    property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0
    property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }


    property bool _show: false   // true when a media-key step should pop the OSD

    Timer {
        id: hideTimer
        interval: root.hideInterval
        repeat: false
        onTriggered: root.visible = false
    }

    // Two separate Process instances — one for silent info reads, one
    // for set commands — so a `brightnessUp` mid-prime can't drop the
    // initial info reply.
    CheckedProcess {
        id: brightReadProc
        label: "brightnessctl info"
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.onBrightnessRead(text)
        }
    }

    CheckedProcess {
        id: brightSetProc
        label: "brightnessctl set"
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.onBrightnessSet(text)
        }
    }

    function volumeUp() {
        var sink = Pipewire.defaultAudioSink
        if (sink && sink.audio) {
            sink.audio.volume = Math.min(1, sink.audio.volume + Theme.volumeStep)
            showVolume()
        }
    }

    function volumeDown() {
        var sink = Pipewire.defaultAudioSink
        if (sink && sink.audio) {
            sink.audio.volume = Math.max(0, sink.audio.volume - Theme.volumeStep)
            showVolume()
        }
    }

    function volumeMute() {
        var sink = Pipewire.defaultAudioSink
        if (sink && sink.audio) {
            sink.audio.muted = !sink.audio.muted
            showVolume()
        }
    }

    function showVolume() {
        root.activeKind = "volume"
        root.value = root.muted ? 0 : root.volume
        root.glyph = root.volumeGlyph()
        root.visible = true
        hideTimer.restart()
    }

    function volumeGlyph() {
        if (root.muted) return Icon.volumeMute
        if (root.volume < root.volumeGlyphThreshold) return Icon.volumeLow
        return Icon.volumeHigh
    }

    function micMute() {
        var src = Pipewire.defaultAudioSource
        if (src && src.audio) {
            src.audio.muted = !src.audio.muted
            root.activeKind = "mic"
            root.value = src.audio.muted ? 0 : (src.audio.volume ?? 0)
            root.glyph = src.audio.muted ? Icon.micMute : Icon.mic
            root.visible = true
            hideTimer.restart()
        }
    }

    // Show the OSD synchronously (matching the volume path) using the
    // predicted next brightness so the user sees feedback before the
    // `brightnessctl` reply lands. The reply corrects any drift (e.g.
    // hardware clamping the value).
    function brightnessUp() {
        var pct = Math.round(root.brightnessValue * 100)
        var next = Math.min(100, pct + root.brightnessStep) / 100
        root.brightnessValue = next
        root.showBrightness(next, Icon.brightness)
        brightSetProc.command = ["brightnessctl", "s", "+" + root.brightnessStep + "%"]
        brightSetProc.running = true
    }

    // Brightness-down floor guard. Reads `brightnessValue` (the dedicated
    // brightness cache) so a prior volume or mic popup can't poison the
    // check — pre-fix, `value` got overwritten by `showVolume`/`micMute`
    // and `brightnessDown` would parse the audio fraction as brightness.
    function brightnessDown() {
        var pct = Math.round(root.brightnessValue * 100)
        if (pct <= root.brightnessMin) return  // already at or below the floor
        var nextPct
        // Would the step underflow? Set the floor directly rather than
        // overshoot to a screen-blanking 0%.
        if (pct - root.brightnessStep < root.brightnessMin)
            nextPct = root.brightnessMin
        else
            nextPct = pct - root.brightnessStep
        root.brightnessValue = nextPct / 100
        root.showBrightness(nextPct / 100, Icon.brightness)
        if (nextPct === root.brightnessMin)
            brightSetProc.command = ["brightnessctl", "s", String(root.brightnessMin) + "%"]
        else
            brightSetProc.command = ["brightnessctl", "s", root.brightnessStep + "%-"]
        brightSetProc.running = true
    }

    function showBrightness(fraction, glyph) {
        root.activeKind = "brightness"
        root.value = fraction
        root.glyph = glyph
        root.visible = true
        hideTimer.restart()
    }

    function refreshBrightness() {
        brightReadProc.running = true
    }

    // onBrightnessSet: confirm/correct the predicted value from
    // brightnessctl's set reply. Pops the OSD only if `_show` is true
    // (which it is for normal key presses; the silent prime only happens
    // via onBrightnessRead below).
    function onBrightnessSet(text) {
        var m = text.match(/\((\d+)%\)/)
        var pct = m ? parseInt(m[1]) / 100 : 0
        if (!isFinite(pct) || pct <= 0) return
        root.brightnessValue = pct
        if (root._show && root.activeKind === "brightness") {
            // Correct the optimistic popup value to the real one.
            root.value = pct
        }
    }

    // onBrightnessRead: silent prime at startup (or any future refresh).
    // Caches the value and arms `_show`; never pops the OSD.
    function onBrightnessRead(text) {
        var m = text.match(/\((\d+)%\)/)
        var pct = m ? parseInt(m[1]) / 100 : 0
        if (isFinite(pct) && pct > 0) root.brightnessValue = pct
        root._show = true
    }

    Component.onCompleted: {
        // Prime the brightness cache silently (no OSD pop on startup).
        // `_show` is armed inside onBrightnessRead — setting it here
        // would race the async process and a stray key press could pop
        // the OSD before the cache lands.
        root._show = false
        refreshBrightness()
    }
}