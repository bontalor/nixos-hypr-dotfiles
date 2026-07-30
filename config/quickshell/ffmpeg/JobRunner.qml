import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: runner

    property string label: ""
    property string output: ""
    property real durationSec: 0
    property real outTimeSec: 0
    // Renamed from `state` — that property already exists on QQuickItem
    // (the visual state machine), and overriding it triggered a qmllint
    // property-override warning plus shadowed any future use of the
    // base Item's state machine on this Item.
    // Values: "idle" | "running" | "done" | "failed" | "cancelled".
    property string phase: "idle"
    property string error: ""

    readonly property bool running: proc.running
    readonly property real progress: durationSec > 0 ? Math.min(1, outTimeSec / durationSec) : 0

    signal started()
    signal finished(string label, string output)
    signal failed(string label, string error, int exitCode)
    signal cancelled(string output)
    signal busy()

    function start(jobLabel, args, outFile, jobDurationSec) {
        if (runner.phase !== "idle" && runner.phase !== "done"
            && runner.phase !== "failed" && runner.phase !== "cancelled") {
            busy()
            return false
        }
        if (proc.running) { busy(); return false }
        runner.phase = "idle"   // reset any terminal state from a prior run
        label = jobLabel
        output = outFile
        durationSec = jobDurationSec
        outTimeSec = 0
        error = ""
        proc.command = ["ffmpeg", "-nostdin", "-v", "warning",
                        "-progress", "pipe:1", "-nostats"].concat(args)
        phase = "running"
        proc.running = true
        started()
        return true
    }

    function cancel() {
        if (!proc.running) return
        phase = "cancelled"
        proc.running = false
    }

    Component.onDestruction: if (proc.running) {
        // Mark cancelled BEFORE terminating so the close-of-shell
        // doesn't churn through onExited's failure branch and emit a
        // spurious "ffmpeg failed (exit 143)" toast to a user who just
        // closed the panel. Mirrors `cancel()`'s ordering.
        runner.phase = "cancelled"
        proc.running = false
    }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("out_time_us=")) {
                    var us = parseInt(line.slice(12), 10)
                    if (!isNaN(us)) runner.outTimeSec = us / 1e6
                }
            }
        }
        stderr: StdioCollector { id: errCollector }
        onExited: (exitCode) => {
            if (runner.phase === "cancelled") {
                // Spawn cleanup detached so concurrent cancels don't
                // share one Process and drop rm invocations.
                Quickshell.execDetached({ command: ["rm", "-f", runner.output] })
                runner.cancelled(runner.output)
                // Defer the idle reset so consumers bound to `phase`
                // observe "cancelled" before it flips to "idle".
                Qt.callLater(() => { runner.phase = "idle" })
                return
            }
            if (exitCode === 0) {
                runner.phase = "done"
                runner.outTimeSec = runner.durationSec
                runner.finished(runner.label, runner.output)
            } else {
                runner.phase = "failed"
                runner.error = (errCollector.text || "").trim().slice(-500)
                runner.failed(runner.label, runner.error, exitCode)
            }
            // Defer the idle reset so `finished`/`failed` consumers
            // observe a stable phase value within their handler.
            Qt.callLater(() => { runner.phase = "idle" })
        }
    }
}