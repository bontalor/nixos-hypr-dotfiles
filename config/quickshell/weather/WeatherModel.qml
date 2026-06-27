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
        var json = JSON.parse(text)
        if (json && json.current_condition && json.current_condition[0]) {
            weatherData = json
            dataReady = true
            updateMoonData()
        }
    }

    function moonLunarAge() {
        var now = new Date()
        var y = now.getFullYear()
        var m = now.getMonth() + 1
        var d = now.getDate()
        var h = now.getHours()
        var mn = now.getMinutes()
        var s = now.getSeconds()
        if (m <= 2) { y -= 1; m += 12 }
        var a = Math.floor(y / 100)
        var b = 2 - a + Math.floor(a / 4)
        var jd = Math.floor(365.25 * (y + 4716)) + Math.floor(30.6001 * (m + 1)) + d + b - 1524.5
        jd += h / 24 + mn / 1440 + s / 86400
        var days = jd - 2451550.226
        var cycles = days / 29.530587
        return (cycles - Math.floor(cycles)) * 29.530587
    }

    function calcMoonPhase() {
        var age = moonLunarAge()
        if (age < 1.5 || age >= 28.0) return "New Moon"
        if (age < 6.4) return "Waxing Crescent"
        if (age < 8.4) return "First Quarter"
        if (age < 13.3) return "Waxing Gibbous"
        if (age < 16.2) return "Full Moon"
        if (age < 21.1) return "Waning Gibbous"
        if (age < 23.1) return "Last Quarter"
        return "Waning Crescent"
    }

    function calcMoonIcon() {
        var p = calcMoonPhase().toLowerCase()
        if (p.includes("new")) return "\uD83C\uDF11"
        if (p.includes("waxing crescent")) return "\uD83C\uDF12"
        if (p.includes("first quarter")) return "\uD83C\uDF13"
        if (p.includes("waxing gibbous")) return "\uD83C\uDF14"
        if (p.includes("full")) return "\uD83C\uDF15"
        if (p.includes("waning gibbous")) return "\uD83C\uDF16"
        if (p.includes("last quarter")) return "\uD83C\uDF17"
        if (p.includes("waning crescent")) return "\uD83C\uDF18"
        return ""
    }

    function calcMoonIllumination() {
        var age = moonLunarAge()
        return Math.round(50 * (1 - Math.cos(2 * Math.PI * age / 29.530587)))
    }

    function calcNextFullMoon() {
        var age = moonLunarAge()
        var daysUntilFull = (14.765 - age + 29.530587) % 29.530587
        if (daysUntilFull < 0.5) return "Today"
        if (daysUntilFull < 1.5) return "Tomorrow"
        var today = new Date()
        var nextFull = new Date(today)
        nextFull.setDate(today.getDate() + Math.round(daysUntilFull))
        var y = nextFull.getFullYear()
        var m = String(nextFull.getMonth() + 1).padStart(2, '0')
        var d = String(nextFull.getDate()).padStart(2, '0')
        return y + "-" + m + "-" + d
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
        // 15 degrees longitude ≈ 1 hour timezone offset
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
        // Convert current UTC to minutes-since-midnight at the location
        var utcNow = new Date()
        var locationMinutes = ((utcNow.getUTCHours() * 60 + utcNow.getUTCMinutes() + offset) % 1440 + 1440) % 1440
        var sunriseMinutes = parseTimeToMinutes(a.sunrise)
        var sunsetMinutes = parseTimeToMinutes(a.sunset)
        return locationMinutes < sunriseMinutes || locationMinutes >= sunsetMinutes
    }

    function updateMoonData() {
        root.isNight = calcIsNight()
        root.moonPhase = calcMoonPhase()
        root.moonIcon = calcMoonIcon()
        root.moonIllumination = calcMoonIllumination()
        root.nextFullMoon = calcNextFullMoon()
    }

    Timer {
        id: moonTimer
        interval: 60000
        repeat: true
        running: root.dataReady
        onTriggered: updateMoonData()
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
