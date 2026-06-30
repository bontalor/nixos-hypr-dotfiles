pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persisted key/value preferences for the shell. Replaces the
// near-identical `sh -c "mkdir -p $dir && printf %s $val > $dir/key"`
// writer-Process blocks that were duplicated across BatteryModel
// (selectionWriter) and WeatherModel (unitWriter, cityWriter).
//
// Each feature stores its keys under shellDir/<feature>/<key>.
//
// write(feature, key, value) — fire-and-forget; reuses one Process.
// read(feature, key, callback) — async; callback(trimmedText) fires on
//   completion ("" if the file is missing). Spawns a short-lived
//   Process per read via Component.createObject (idiomatic dynamic
//   creation, unlike Qt.createQmlObject string-based anti-pattern).

Singleton {
    id: root

    function write(feature, key, value) {
        var dir = Quickshell.shellDir + "/" + feature
        writer.command = ["sh", "-c",
            "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/$3\"",
            "sh", dir, String(value), key]
        writer.running = true
    }

    function read(feature, key, callback) {
        var path = Quickshell.shellDir + "/" + feature + "/" + key
        var proc = readerComponent.createObject(root)
        proc.command = ["sh", "-c", "cat \"$1\" 2>/dev/null", "sh", path]
        proc.stdout.streamFinished.connect(function() {
            callback(proc.stdout.text.trim())
            proc.destroy()
        })
        proc.running = true
    }

    Process {
        id: writer
        running: false
    }

    Component {
        id: readerComponent
        Process {
            running: false
            stdout: StdioCollector { waitForEnd: true }
        }
    }
}
