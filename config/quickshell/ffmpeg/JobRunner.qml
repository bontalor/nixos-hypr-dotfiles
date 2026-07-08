import QtQuick
import Quickshell.Io

Item {
    id: runner

    property string label: ""
    property string output: ""
    property real durationSec: 0
    property real outTimeSec: 0
    property string state: "idle"
    property string error: ""
    property bool _cancelRequested: false

    readonly property bool running: proc.running
    readonly property real progress: durationSec > 0 ? Math.min(1, outTimeSec / durationSec) : 0

    signal started()
    signal finished(string label, string output)
    signal failed(string label, string error, int exitCode)
    signal cancelled(string output)
    signal busy()

    function start(jobLabel, args, outFile, jobDurationSec) {
        if (proc.running) {
            busy()
            return false
        }
        label = jobLabel
        output = outFile
        durationSec = jobDurationSec
        outTimeSec = 0
        error = ""
        _cancelRequested = false
        proc.command = ["ffmpeg", "-nostdin", "-v", "warning",
                        "-progress", "pipe:1", "-nostats"].concat(args)
        state = "running"
        proc.running = true
        started()
        return true
    }

    function cancel() {
        if (!proc.running) return
        _cancelRequested = true
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
            if (runner._cancelRequested) {
                runner.state = "cancelled"
                cleanup.command = ["rm", "-f", runner.output]
                cleanup.running = true
                runner.cancelled(runner.output)
                return
            }
            if (exitCode === 0) {
                runner.state = "done"
                runner.outTimeSec = runner.durationSec
                runner.finished(runner.label, runner.output)
            } else {
                runner.state = "failed"
                runner.error = (errCollector.text || "").trim().slice(-500)
                runner.failed(runner.label, runner.error, exitCode)
            }
        }
    }

    Process { id: cleanup; running: false }
}
