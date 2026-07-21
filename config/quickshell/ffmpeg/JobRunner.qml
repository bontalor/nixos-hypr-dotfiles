import QtQuick
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
        // Guard against the cancel-and-immediately-restart race: a
        // previous `cancel()` leaves `proc.running` true briefly until
        // the kernel delivers SIGTERM and `onExited` flips it back.
        // Using `phase === "idle"` as the readiness signal (rather than
        // `proc.running`) avoids spurious "busy" notifications when the
        // SIGTERM latency is longer than the user's click gap. `phase`
        // is reset to "idle" synchronously in onExited below.
        if (runner.phase !== "idle" && runner.phase !== "done"
            && runner.phase !== "failed" && runner.phase !== "cancelled") {
            busy()
            return false
        }
        // If a Process is still winding down (cancel before onExited),
        // also refuse — racing the SIGTERM callback would either drop
        // the new command or dupe onExited back-to-back.
        if (proc.running) { busy(); return false }
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
            // Reset phase to "idle" first so a re-entrant `start()` (e.g.
            // cancel immediately followed by retry) doesn't get rejected
            // as a "running" duplicate. Once phase is flipped, the rest
            // of the branch is dispatched on this event-loop turn.
            if (runner.phase === "cancelled") {
                runner.phase = "idle"
                cleanup.command = ["rm", "-f", runner.output]
                cleanup.running = true
                runner.cancelled(runner.output)
                return
            }
            if (exitCode === 0) {
                runner.phase = "done"
                runner.outTimeSec = runner.durationSec
                runner.finished(runner.label, runner.output)
                runner.phase = "idle"
            } else {
                runner.phase = "failed"
                runner.error = (errCollector.text || "").trim().slice(-500)
                runner.failed(runner.label, runner.error, exitCode)
                runner.phase = "idle"
            }
        }
    }

    Process { id: cleanup; running: false }
}