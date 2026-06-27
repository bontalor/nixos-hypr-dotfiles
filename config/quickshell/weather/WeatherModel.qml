pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var weatherData: ({})
    property bool dataReady: false
    property string degreeUnit: "F"
    property string customCity: ""

    property bool ready: false
    property bool retryingFallback: false
    property bool fetchRunning: false
    property bool needsRefetch: false

    function fetchWeather() {
        if (fetchRunning) {
            needsRefetch = true
            return
        }
        fetchRunning = true
        var url = "https://wttr.in/"
        if (customCity && !retryingFallback) url += encodeURIComponent(customCity) + "?format=j1"
        else url += "?format=j1"
        fetchProc.command = ["curl", "-s", "-m", "10", url]
        fetchProc.running = true
    }

    Process {
        id: fetchProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                fetchRunning = false
                parseWeather(text)
                if (!dataReady && customCity && !retryingFallback) {
                    retryingFallback = true
                    fetchWeather()
                    return
                }
                retryingFallback = false
                if (needsRefetch) {
                    needsRefetch = false
                    fetchWeather()
                }
            }
        }
    }

    function parseWeather(text) {
        var json = JSON.parse(text)
        if (json && json.current_condition && json.current_condition[0]) {
            weatherData = json
            dataReady = true
        }
    }

    Timer {
        interval: 600000
        repeat: true
        running: true
        onTriggered: fetchWeather()
    }

    Process {
        id: unitWriter
        running: false
    }

    Process {
        id: cityWriter
        running: false
    }

    onDegreeUnitChanged: {
        if (!ready) return
        var dir = Quickshell.shellDir + "/weather"
        unitWriter.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1\"/unit", "sh", dir, degreeUnit]
        unitWriter.running = true
    }

    onCustomCityChanged: {
        if (!ready) return
        var dir = Quickshell.shellDir + "/weather"
        cityWriter.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1\"/city", "sh", dir, customCity]
        cityWriter.running = true
    }

    Process {
        id: startupReader
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var lines = text.split('\n')
                if (lines[0].trim()) root.degreeUnit = lines[0].trim()
                if (lines[1].trim()) root.customCity = lines[1].trim()
                root.ready = true
                fetchWeather()
            }
        }
    }

    Component.onCompleted: {
        var dir = Quickshell.shellDir + "/weather"
        startupReader.command = ["sh", "-c",
            "printf '%s\\n' \"$(cat \"$1/unit\" 2>/dev/null)\" \"$(cat \"$1/city\" 2>/dev/null)\"",
            "sh", dir]
        startupReader.running = true
    }
}
