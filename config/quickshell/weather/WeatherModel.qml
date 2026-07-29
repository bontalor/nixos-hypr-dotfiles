pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../util"

// Wttr.in-backed weather state. Fetches JSON on demand via
// XMLHttpRequest (built into QML — no curl dependency), computes moon
// phase once per fetch (rather than recomputing every minute), and
// refreshes on a long interval gated on `dataReady` so a newly-spawned
// shell doesn't fire a second network request before the first completes.
//
// A short retry timer fires if the first fetch fails so a headless boot
// with no network at startup doesn't stay weatherless forever.

Singleton {
    id: root

    // Refetch interval once the first fetch has succeeded (10 min —
    // wttr.in itself caches upstream data on a similar window).
    readonly property int refreshMillis: 600000

    property var weatherData: ({})
    property bool dataReady: false

    // Unit and city are PrefStore-backed; the Settings panel writes the
    // prefs and these bindings follow (PrefStore loads synchronously via
    // FileView blockLoading, so the values are right from the first read).
    readonly property string degreeUnit: PrefStore.weatherUnit || "F"
    readonly property string customCity: PrefStore.weatherCity

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
             + (degreeUnit === "F" ? c.temp_F : c.temp_C) + "°" + degreeUnit
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
        if (customCity && !retryingFallback) url += encodeURIComponent(customCity)
        url += "?format=j1"

        var xhr = new XMLHttpRequest()
        xhr.timeout = 10000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            fetchRunning = false
            if (xhr.status === 200) {
                parseWeather(xhr.responseText)
            } else if (!dataReady) {
                // status 0 covers timeouts and network-down.
                fetchError = xhr.status ? "HTTP " + xhr.status : "no network"
            }
            // A custom city that fails (bad name, wttr.in hiccup) falls
            // back to one auto-location (IP-based) attempt.
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
        xhr.open("GET", url)
        xhr.send()
    }

    function parseWeather(text) {
        var json
        try {
            json = JSON.parse(text)
        } catch (e) {
            // wttr.in returned an error page or empty body; leave prior
            // data intact but surface the failure so the panel can show
            // "fetch failed" and the retry timer can fire.
            if (!dataReady) fetchError = "fetch failed"
            return
        }
        if (json && json.current_condition && json.current_condition[0]) {
            weatherData = json
            dataReady = true
            fetchError = ""
            _lastFetchMs = Date.now()
            updateMoonData()
        } else if (!dataReady) {
            fetchError = "no data"
        }
    }

    property int _lastFetchMs: 0   // last successful fetch timestamp

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

    // Visibility gate: refetch only while a consumer (the bar's weather
    // chip or the WeatherPanel) — or an eager-fallback retry — needs
    // data. Saves the app-server wakeup cost when nobody is looking at
    // the panel AND the bar's chip isn't rendered (still rendered →
    // still considered a consumer; the bar widget is always visible).
    property bool panelVisible: false
    readonly property bool widgetVisible: true   // bar's WeatherWidget is always rendered
    readonly property bool anyConsumerVisible: root.panelVisible || root.widgetVisible

    // Only poll after the first fetch completes (or the user opens the
    // panel) — running before `dataReady` would race with startup.
    Timer {
        interval: root.refreshMillis
        repeat: true
        running: root.dataReady && root.anyConsumerVisible
        onTriggered: root.fetchWeather()
    }

    // Retry-on-failure: if the first fetch fails (no network at boot),
    // try again every 60s until success. Without this, the main refresh
    // timer (gated on `dataReady`) would never start.
    Timer {
        interval: 60000
        repeat: true
        running: !root.dataReady && root.ready && !root.fetchRunning
        onTriggered: root.fetchWeather()
    }

    // A city change (from Settings) refetches immediately; unit changes
    // don't need to — wttr.in returns both °F and °C in every payload.
    onCustomCityChanged: if (ready) fetchWeather()

    Component.onCompleted: {
        root.ready = true
        fetchWeather()
    }
}
