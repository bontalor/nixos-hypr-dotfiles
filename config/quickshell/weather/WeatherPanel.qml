import "../theme"
import "WeatherCodes.js" as WeatherCodes
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: root
    title: "Weather"
    color: "transparent"
    implicitWidth: 850
    implicitHeight: 450
    visible: false

    onClosed: visible = false

    property int selSection: 0
    property bool inSection: false
    property int selDevice: 0

    property var sections: [
        { name: "Weather" },
        { name: "Astronomy" },
        { name: "Location" },
        { name: "Configuration" }
    ]

    property string customCity: ""
    property string degreeUnit: "F"
    property bool configExpanded: false
    property int selConfigItem: 0
    property int selConfigProfile: 0
    property var weatherData: ({})
    property bool dataReady: false

    property int selCity: 0
    property bool cityEditing: false
    property string cityInputText: ""

    Timer {
        id: focusTimer
        interval: 0
        onTriggered: {
            mainRect.forceActiveFocus()
        }
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
        var dir = Quickshell.shellDir + "/weather"
        unitWriter.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1\"/unit", "sh", dir, degreeUnit]
        unitWriter.running = true
    }

    onCustomCityChanged: {
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
                var dir = Quickshell.shellDir + "/weather"
                var lines = text.split('\n')
                if (lines[0].trim()) root.degreeUnit = lines[0].trim()
                if (lines[1].trim()) root.customCity = lines[1].trim()
                unitWriter.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1\"/unit", "sh", dir, root.degreeUnit]
                unitWriter.running = true
                cityWriter.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1\"/city", "sh", dir, root.customCity]
                cityWriter.running = true
                fetchWeather()
            }
        }
    }

    Component.onCompleted: {
        var dir = Quickshell.shellDir + "/weather"
        startupReader.command = ["sh", "-c",
            "cat \"$1/unit\" 2>/dev/null || echo F; cat \"$1/city\" 2>/dev/null || echo ''",
            "sh", dir]
        startupReader.running = true
    }

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
                parseWeatherData(text)
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

    Timer {
        interval: 600000
        repeat: true
        running: root.visible
        onTriggered: fetchWeather()
    }

    function currentModelLength() {
        switch (selSection) {
        case 0: return dataReady ? 1 : 0
        case 1: return dataReady ? 1 : 0
        case 2: return dataReady ? 1 : 0
        case 3: return 2
        default: return 0
        }
    }

    onVisibleChanged: {
        if (visible) {
            fetchWeather()
            mainRect.forceActiveFocus()
            selSection = 0
            inSection = false
            selDevice = 0
            configExpanded = false
            cityEditing = false
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
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

    function moonPhase() {
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

    function moonIllumination() {
        var age = moonLunarAge()
        return Math.round(50 * (1 - Math.cos(2 * Math.PI * age / 29.530587)))
    }

    function moonIcon() {
        var p = moonPhase().toLowerCase()
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

    function nextFullMoon() {
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

    Rectangle {
        id: mainRect
        anchors.fill: parent
        color: "transparent"
        focus: true

        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_Tab:
                if (selSection === 3 && inSection) {
                    if (configExpanded) {
                        configExpanded = false
                    } else {
                        configExpanded = true
                        selConfigProfile = 0
                    }
                } else if (event.modifiers & Qt.ShiftModifier) {
                    if (inSection) {
                        inSection = false
                    } else {
                        selSection = Math.max(selSection - 1, 0)
                    }
                } else if (inSection) {
                    var maxD = currentModelLength() - 1
                    selDevice = Math.min(selDevice + 1, Math.max(0, maxD))
                } else {
                    inSection = true
                    selDevice = 0
                }
                event.accepted = true; break
            case Qt.Key_Backtab:
                if (selSection === 3 && configExpanded) {
                    configExpanded = false
                } else if (inSection) {
                    inSection = false
                }
                event.accepted = true; break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (selSection === 3 && inSection && configExpanded) {
                    if (selConfigItem === 0) {
                        if (selConfigProfile === 0) {
                            customCity = ""
                            configExpanded = false
                            fetchWeather()
                        } else if (selConfigProfile === 1) {
                            if (!cityEditing) {
                                cityEditing = true
                                cityInputText = customCity || ""
                            } else {
                                customCity = cityInputText
                                cityEditing = false
                                configExpanded = false
                                fetchWeather()
                                mainRect.forceActiveFocus()
                            }
                        }
                    } else if (selConfigItem === 1) {
                        if (selConfigProfile === 0) degreeUnit = "F"
                        else if (selConfigProfile === 1) degreeUnit = "C"
                        configExpanded = false
                    }
                } else if (selSection === 3 && inSection && !configExpanded) {
                    configExpanded = true
                    selConfigProfile = 0
                } else if (!inSection) {
                    inSection = true
                    selDevice = 0
                }
                event.accepted = true; break
            case Qt.Key_J:
            case Qt.Key_Down:
                if (selSection === 3 && configExpanded && inSection) {
                    var plen = selConfigItem === 0 ? 2 : 2
                    selConfigProfile = Math.min(selConfigProfile + 1, Math.max(0, plen - 1))
                } else if (selSection === 3 && inSection) {
                    selConfigItem = Math.min(selConfigItem + 1, Math.max(0, 1))
                } else if (inSection) {
                    var maxD = currentModelLength() - 1
                    selDevice = Math.min(selDevice + 1, Math.max(0, maxD))
                } else {
                    selSection = Math.min(selSection + 1, sections.length - 1)
                }
                event.accepted = true; break
            case Qt.Key_K:
            case Qt.Key_Up:
                if (selSection === 3 && configExpanded && inSection) {
                    selConfigProfile = Math.max(selConfigProfile - 1, 0)
                } else if (selSection === 3 && inSection) {
                    selConfigItem = Math.max(selConfigItem - 1, 0)
                } else if (inSection) {
                    selDevice = Math.max(selDevice - 1, 0)
                } else {
                    selSection = Math.max(selSection - 1, 0)
                }
                event.accepted = true; break
            case Qt.Key_Escape:
                if (cityEditing) {
                    cityEditing = false
                    mainRect.forceActiveFocus()
                } else if (selSection === 3 && configExpanded) {
                    configExpanded = false
                } else {
                    root.visible = false
                }
                event.accepted = true; break
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                width: (parent.width - parent.spacing) * 0.25
                height: parent.height
                color: Qt.alpha(Colors.base00, 0.75)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Repeater {
                        model: sections

                        delegate: Rectangle {
                            width: parent.width
                            height: 30
                            color: selSection === index ? Qt.alpha(Colors.base01, 0.75) : "transparent"

                            Text {
                                text: modelData.name
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    right: parent.right; rightMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                elide: Text.ElideRight
                                leftPadding: selSection === index && inSection ? 18 : 0
                            }

                            Text {
                                text: "\u25b6"
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                visible: selSection === index && inSection
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    selSection = index
                                    inSection = false
                                    configExpanded = false
                                    mainRect.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: (parent.width - parent.spacing) * 0.75
                height: parent.height
                color: Qt.alpha(Colors.base00, 0.75)

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 10
                    contentHeight: contentCol.height
                    clip: true

                    function scrollToVisible(itemY, itemH) {
                        var viewH = flick.height
                        var maxY = Math.max(0, contentCol.height - viewH)
                        if (itemY < flick.contentY) {
                            flick.contentY = Math.max(0, itemY - 40)
                        } else if (itemY + itemH > flick.contentY + viewH) {
                            flick.contentY = Math.min(maxY, itemY + itemH - viewH + 10)
                        }
                    }

                    function scrollToSelection() {
                        var y, h
                        if (selSection < 3 && inSection) {
                            y = 40 + selDevice * 55
                            h = 45
                        } else if (selSection === 3 && inSection) {
                            if (configExpanded) {
                                y = 40 + selConfigItem * 55 + 45 + selConfigProfile * 30
                                h = 30
                            } else {
                                y = 40 + selConfigItem * 55
                                h = 45
                            }
                        }
                        if (y !== undefined) flick.scrollToVisible(y, h)
                    }

                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            width: parent.width
                            height: 30
                            color: Qt.alpha(Colors.base0d, 0.75)

                            Text {
                                text: sections[selSection]?.name ?? ""
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: selSection === 0

                            Item {
                                width: parent.width
                                height: dataReady ? 30 * 10 : 30

                                Column {
                                    anchors.fill: parent
                                    spacing: 10

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? WeatherCodes.icon(parseInt(weatherData.current_condition[0].weatherCode)) + "  " + (degreeUnit === "F" ? weatherData.current_condition[0].temp_F : weatherData.current_condition[0].temp_C) + "\u00b0" + degreeUnit : ""
                                        color: Colors.foreground
                                        font.pixelSize: 32
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.bold: true
                                    }

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? WeatherCodes.desc(parseInt(weatherData.current_condition[0].weatherCode)) : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? "Feels like " + (degreeUnit === "F" ? weatherData.current_condition[0].FeelsLikeF : weatherData.current_condition[0].FeelsLikeC) + "\u00b0" + degreeUnit : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? "Humidity: " + weatherData.current_condition[0].humidity + "%" : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? "Wind: " + weatherData.current_condition[0].windspeedKmph + " km/h " + weatherData.current_condition[0].winddir16Point : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? "UV Index: " + weatherData.current_condition[0].uvIndex : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? "Pressure: " + weatherData.current_condition[0].pressure + " mb" : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? "Visibility: " + weatherData.current_condition[0].visibility + " km" : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? "Cloud cover: " + weatherData.current_condition[0].cloudcover + "%" : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: !dataReady
                                        text: "Fetching weather data..."
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: selSection === 1

                            Item {
                                width: parent.width
                                height: dataReady ? 30 * 6 : 30

                                Column {
                                    anchors.fill: parent
                                    spacing: 10

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? moonIcon() + "  " + moonPhase() : ""
                                        color: Colors.foreground
                                        font.pixelSize: 32
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.bold: true

                                    }

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? "Illumination: " + moonIllumination() + "%" : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: dataReady && weatherData.weather && weatherData.weather[0] && weatherData.weather[0].astronomy
                                        text: dataReady && weatherData.weather && weatherData.weather[0] && weatherData.weather[0].astronomy
                                            ? "Moonrise: " + weatherData.weather[0].astronomy[0].moonrise
                                            : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: dataReady && weatherData.weather && weatherData.weather[0] && weatherData.weather[0].astronomy
                                        text: dataReady && weatherData.weather && weatherData.weather[0] && weatherData.weather[0].astronomy
                                            ? "Moonset: " + weatherData.weather[0].astronomy[0].moonset
                                            : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? "Next full moon: " + nextFullMoon() : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: !dataReady
                                        text: "Fetching astronomy data..."
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: selSection === 2

                            Item {
                                width: parent.width
                                height: dataReady ? 30 * 3 : 30

                                Column {
                                    anchors.fill: parent
                                    spacing: 10

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? weatherData.nearest_area[0].areaName[0].value : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: dataReady
                                        text: dataReady ? weatherData.nearest_area[0].region[0].value + ", " + weatherData.nearest_area[0].country[0].value : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: dataReady
                                        text: "Using: " + (customCity || "Auto (IP)")
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: !dataReady
                                        text: "Fetching location data..."
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: selSection === 3

                            Item {
                                width: parent.width
                                height: (configExpanded && 0 === selConfigItem && inSection)
                                        ? 45 + 2 * 30
                                        : 45

                                Rectangle {
                                    anchors.fill: parent
                                    color: (!configExpanded && inSection && 0 === selConfigItem)
                                           || (configExpanded && inSection && 0 === selConfigItem)
                                           ? Qt.alpha(Colors.base01, 0.75) : "transparent"
                                }

                                Column {
                                    width: parent.width

                                    Item {
                                        width: parent.width
                                        height: 45

                                        Text {
                                            text: "City: " + (customCity || "Auto")
                                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                            color: Colors.foreground
                                            font.pixelSize: 16
                                            font.family: "JetBrainsMono Nerd Font"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (!inSection) { inSection = true }
                                                if (configExpanded && 0 === selConfigItem) {
                                                    configExpanded = false
                                                } else {
                                                    selConfigItem = 0
                                                    configExpanded = true
                                                    selConfigProfile = 0
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        height: visible ? 2 * 30 : 0
                                        visible: configExpanded && inSection && 0 === selConfigItem

                                        Rectangle {
                                            width: parent.width
                                            height: 30
                                            color: 0 === selConfigProfile
                                                    ? Qt.alpha(Colors.base0d, 0.75)
                                                    : Qt.alpha(Colors.base00, 0.75)

                                            Text {
                                                text: "Auto (IP)"
                                                anchors { left: parent.left; leftMargin: 30; verticalCenter: parent.verticalCenter }
                                                color: Colors.foreground
                                                font.pixelSize: 16
                                                font.family: "JetBrainsMono Nerd Font"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (inSection) {
                                                        customCity = ""
                                                        configExpanded = false
                                                        fetchWeather()
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 30
                                            color: !cityEditing && 1 === selConfigProfile
                                                    ? Qt.alpha(Colors.base0d, 0.75)
                                                    : Qt.alpha(Colors.base00, 0.75)

                                            Text {
                                                text: "Custom..."
                                                anchors { left: parent.left; leftMargin: 30; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                                color: Colors.foreground
                                                font.pixelSize: 16
                                                font.family: "JetBrainsMono Nerd Font"
                                                visible: !cityEditing
                                            }

                                            TextInput {
                                                visible: cityEditing
                                                anchors { left: parent.left; leftMargin: 30; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                                color: Colors.foreground
                                                font.pixelSize: 16
                                                font.family: "JetBrainsMono Nerd Font"
                                                text: cityInputText
                                                focus: cityEditing
                                                onAccepted: {
                                                    customCity = text
                                                    cityEditing = false
                                                    configExpanded = false
                                                    fetchWeather()
                                                    mainRect.forceActiveFocus()
                                                }
                                                Keys.onPressed: (event) => {
                                                    if (event.key === Qt.Key_Escape) {
                                                        cityEditing = false
                                                        mainRect.forceActiveFocus()
                                                        event.accepted = true
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (inSection) {
                                                        if (!cityEditing) {
                                                            cityEditing = true
                                                            cityInputText = customCity || ""
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: (configExpanded && 1 === selConfigItem && inSection)
                                        ? 45 + 2 * 30
                                        : 45

                                Rectangle {
                                    anchors.fill: parent
                                    color: (!configExpanded && inSection && 1 === selConfigItem)
                                           || (configExpanded && inSection && 1 === selConfigItem)
                                           ? Qt.alpha(Colors.base01, 0.75) : "transparent"
                                }

                                Column {
                                    width: parent.width

                                    Item {
                                        width: parent.width
                                        height: 45

                                        Text {
                                            text: "Unit: \u00b0" + degreeUnit
                                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                            color: Colors.foreground
                                            font.pixelSize: 16
                                            font.family: "JetBrainsMono Nerd Font"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (!inSection) { inSection = true }
                                                if (configExpanded && 1 === selConfigItem) {
                                                    configExpanded = false
                                                } else {
                                                    selConfigItem = 1
                                                    configExpanded = true
                                                    selConfigProfile = 0
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        height: visible ? 2 * 30 : 0
                                        visible: configExpanded && inSection && 1 === selConfigItem

                                        Rectangle {
                                            width: parent.width
                                            height: 30
                                            color: 0 === selConfigProfile
                                                    ? Qt.alpha(Colors.base0d, 0.75)
                                                    : Qt.alpha(Colors.base00, 0.75)

                                            Text {
                                                text: "Fahrenheit"
                                                anchors { left: parent.left; leftMargin: 30; verticalCenter: parent.verticalCenter }
                                                color: Colors.foreground
                                                font.pixelSize: 16
                                                font.family: "JetBrainsMono Nerd Font"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (inSection) {
                                                        degreeUnit = "F"
                                                        configExpanded = false
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 30
                                            color: 1 === selConfigProfile
                                                    ? Qt.alpha(Colors.base0d, 0.75)
                                                    : Qt.alpha(Colors.base00, 0.75)

                                            Text {
                                                text: "Celsius"
                                                anchors { left: parent.left; leftMargin: 30; verticalCenter: parent.verticalCenter }
                                                color: Colors.foreground
                                                font.pixelSize: 16
                                                font.family: "JetBrainsMono Nerd Font"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (inSection) {
                                                        degreeUnit = "C"
                                                        configExpanded = false
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
