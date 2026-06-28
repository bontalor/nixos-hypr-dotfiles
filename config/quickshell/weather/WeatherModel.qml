pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../util"
import "../theme"

// Wttr.in-backed weather state. Fetches JSON on demand, computes moon
// phase once per fetch (rather than recomputing every minute), and
// refreshes on a long interval gated on `dataReady` so a newly-spawned
// shell doesn't fire a second network request before the first completes.

Singleton {
    id: root

    property var weatherData: ({})
    property bool dataReady: false
    property string degreeUnit: "F"
    property string customCity: ""

    property bool isNight: false
    property string moonPhase: ""
    property string moonIcon: ""
    property int moonIllumination: 0
    property string nextFullMoon: ""

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
        var json
        try {
            json = JSON.parse(text)
        } catch (e) {
            // curl returned an error page or empty string; leave prior data intact.
            return
        }
        if (json && json.current_condition && json.current_condition[0]) {
            weatherData = json
            dataReady = true
            updateMoonData()
        }
    }

    function parseTimeToMinutes(timeStr) {
        var parts = timeStr.split(" ")
        var timeParts = parts[0].split(":")
        var hours = parseInt(timeParts[0])
        var minutes = parseInt(timeParts[1])
        var ampm = parts[1]
        if (ampm === "PM" && hours !== 12) hours += 12
        if (ampm === "AM" && hours === 12) hours = 0
        return hours * 60 + minutes
    }

    function getLocationTimezoneOffsetMinutes() {
        var area = weatherData.nearest_area
        if (!area || !area.length) return 0
        var lon = area[0].longitude
        if (lon === undefined || lon === null) return 0
        // 15 degrees longitude ≈ 1 hour offset (approximation)
        return Math.round(lon / 15) * 60
    }

    function calcIsNight() {
        if (!dataReady) return false
        var weather = weatherData.weather
        if (!weather || !weather.length) return false
        var astro = weather[0].astronomy
        if (!astro || !astro.length) return false
        var a = astro[0]
        if (!a.sunrise || !a.sunset) return false
        var offset = getLocationTimezoneOffsetMinutes()
        var utcNow = new Date()
        var locationMinutes = ((utcNow.getUTCHours() * 60 + utcNow.getUTCMinutes() + offset) % 1440 + 1440) % 1440
        var sunriseMinutes = parseTimeToMinutes(a.sunrise)
        var sunsetMinutes = parseTimeToMinutes(a.sunset)
        return locationMinutes < sunriseMinutes || locationMinutes >= sunsetMinutes
    }

    // Moon phase is recomputed once per fetch — its values barely move
    // within a wttr.in refresh window (the prior moonTimer ticked every
    // 60s and was oversampled by ~1440x).
    function updateMoonData() {
        var age = Util.lunarAge()
        root.isNight = calcIsNight()
        root.moonPhase = Util.moonPhaseName(age)
        root.moonIcon = Util.moonPhaseIcon(root.moonPhase)
        root.moonIllumination = Util.moonIllumination(age)
        root.nextFullMoon = Util.nextFullMoon(age)
    }

    // Only poll after the first fetch completes (or the user opens the
    // panel) — running before `dataReady` would race with startup.
    Timer {
        interval: 600000
        repeat: true
        running: root.dataReady
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