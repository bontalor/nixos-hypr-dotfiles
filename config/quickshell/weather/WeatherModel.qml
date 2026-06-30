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
//
// A short retry timer fires if the first fetch fails so a headless boot
// with no network at startup doesn't stay weatherless forever.

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

    // Single source of truth for the bar chip + panel header text.
    // Previously duplicated between WeatherWidget.qml and WeatherPanel.qml
    // with weaker null-guarding in the widget.
    readonly property string currentSummary: {
        if (!dataReady) return ""
        var cc = weatherData.current_condition
        if (!cc || !cc.length) return ""
        var c = cc[0]
        var icon = isNight ? (moonIcon + " ") : ""
        return icon + WeatherCodes.icon(c.weatherCode) + " "
             + (degreeUnit === "F" ? c.temp_F : c.temp_C) + "\u00b0" + degreeUnit
    }

    property bool ready: false
    property bool retryingFallback: false
    property bool fetchRunning: false
    property bool needsRefetch: false

    // Surface fetch errors so the panel can show "fetch failed" instead
    // of stale "fetching..." forever.
    property string fetchError: ""

    function fetchWeather() {
        if (fetchRunning) {
            needsRefetch = true
            return
        }
        fetchRunning = true
        fetchError = ""
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
            // curl returned an error page or empty string; leave prior
            // data intact but surface the failure so the panel can show
            // "fetch failed" and the retry timer can fire.
            if (!dataReady) fetchError = "fetch failed"
            return
        }
        if (json && json.current_condition && json.current_condition[0]) {
            weatherData = json
            dataReady = true
            fetchError = ""
            updateMoonData()
        } else if (!dataReady) {
            fetchError = "no data"
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
        var age = MoonUtil.lunarAge()
        root.isNight = calcIsNight()
        root.moonPhase = MoonUtil.moonPhaseName(age)
        root.moonIcon = MoonUtil.moonPhaseIcon(root.moonPhase)
        root.moonIllumination = MoonUtil.moonIllumination(age)
        root.nextFullMoon = MoonUtil.nextFullMoon(age)
    }

    // Only poll after the first fetch completes (or the user opens the
    // panel) — running before `dataReady` would race with startup.
    Timer {
        interval: Theme.weatherRefreshMillis
        repeat: true
        running: root.dataReady
        onTriggered: fetchWeather()
    }

    // Retry-on-failure: if the first fetch fails (no network at boot),
    // try again every 60s until success. Without this, the main refresh
    // timer (gated on `dataReady`) would never start.
    Timer {
        interval: 60000
        repeat: true
        running: !root.dataReady && root.ready && !root.fetchRunning
        onTriggered: fetchWeather()
    }

    onDegreeUnitChanged: {
        if (!ready) return
        PrefStore.write("weather", "unit", degreeUnit)
    }

    onCustomCityChanged: {
        if (!ready) return
        PrefStore.write("weather", "city", customCity)
    }

    Component.onCompleted: {
        // Read both persisted keys; the second read triggers the first
        // fetch once both are loaded.
        PrefStore.read("weather", "unit", function(text) {
            if (text) root.degreeUnit = text
            PrefStore.read("weather", "city", function(text) {
                if (text) root.customCity = text
                root.ready = true
                fetchWeather()
            })
        })
    }
}
