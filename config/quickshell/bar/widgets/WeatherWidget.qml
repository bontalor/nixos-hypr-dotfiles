import "../../theme"
import "../../weather/WeatherCodes.js" as WeatherCodes
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    width: weatherText.width + 20
    height: 30
    visible: dataReady

    property var weatherData: ({})
    property bool dataReady: false
    property string degreeUnit: "F"
    property string customCity: ""

    function parseWeatherData(text) {
        try {
            var json = JSON.parse(text)
            if (json && json.current_condition && json.current_condition[0]) {
                weatherData = json
                dataReady = true
            }
        } catch (e) {}
    }

    property bool fetchRunning: false
    property bool needsRefetch: false
    property bool retryingFallback: false

    Process {
        id: fetchProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                fetchRunning = false
                parseWeatherData(text)
                if (!dataReady && root.customCity && !retryingFallback) {
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

    Timer {
        id: fetchTimer
        interval: 600000
        repeat: true
        running: false
        onTriggered: fetchWeather()
    }

    Process {
        id: configReader
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var lines = text.split('\n')
                var newUnit = (lines[0] || "F").trim()
                var newCity = (lines[1] || "").trim()
                var changed = newUnit !== root.degreeUnit || newCity !== root.customCity
                root.degreeUnit = newUnit
                root.customCity = newCity
                if (!fetchTimer.running || changed) {
                    fetchWeather()
                    fetchTimer.running = true
                }
            }
        }
    }

    function readConfig() {
        var dir = Quickshell.shellDir + "/weather"
        configReader.command = ["bash", "-c",
            "printf '%s\\n' \"$(cat " + dir + "/unit 2>/dev/null || echo F)\""
            + " \"$(cat " + dir + "/city 2>/dev/null || echo '')\""]
        configReader.running = true
    }

    FileView {
        id: unitWatcher
        path: Quickshell.shellDir + "/weather/unit"
        watchChanges: true
        onFileChanged: readConfig()
    }

    FileView {
        id: cityWatcher
        path: Quickshell.shellDir + "/weather/city"
        watchChanges: true
        onFileChanged: readConfig()
    }

    Component.onCompleted: readConfig()

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? Colors.background : "transparent"
    }

    Text {
        id: weatherText
        anchors.centerIn: parent
        text: dataReady
            ? WeatherCodes.icon(parseInt(weatherData.current_condition[0].weatherCode)) + " " + (degreeUnit === "F" ? weatherData.current_condition[0].temp_F : weatherData.current_condition[0].temp_C) + "\u00b0" + degreeUnit
            : ""
        font.pixelSize: 16
        font.family: "JetBrainsMono Nerd Font"
        color: Colors.foreground
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ipcToggle.running = true
    }

    Process {
        id: ipcToggle
        command: ["qs", "ipc", "call", "overlay", "toggle", "weather"]
        running: false
    }
}
