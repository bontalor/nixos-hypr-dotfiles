import "../theme"
import "."
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

    property bool configExpanded: false
    property int selConfigItem: 0
    property int selConfigProfile: 0

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

    function currentModelLength() {
        switch (selSection) {
        case 0: return WeatherModel.dataReady ? 1 : 0
        case 1: return WeatherModel.dataReady ? 1 : 0
        case 2: return WeatherModel.dataReady ? 1 : 0
        case 3: return 2
        default: return 0
        }
    }

    onVisibleChanged: {
        if (visible) {
            WeatherModel.fetchWeather()
            mainRect.forceActiveFocus()
            selSection = 0
            inSection = false
            selDevice = 0
            configExpanded = false
            cityEditing = false
        }
    }

    readonly property var cc: {
        if (!WeatherModel.dataReady || !WeatherModel.weatherData.current_condition || !WeatherModel.weatherData.current_condition.length)
            return null
        return WeatherModel.weatherData.current_condition[0]
    }

    readonly property var astro: {
        if (!WeatherModel.dataReady || !WeatherModel.weatherData.weather || !WeatherModel.weatherData.weather.length)
            return null
        var w0 = WeatherModel.weatherData.weather[0]
        if (!w0.astronomy || !w0.astronomy.length) return null
        return w0.astronomy[0]
    }

    readonly property var area: {
        if (!WeatherModel.dataReady || !WeatherModel.weatherData.nearest_area || !WeatherModel.weatherData.nearest_area.length)
            return null
        var a0 = WeatherModel.weatherData.nearest_area[0]
        if (!a0.areaName || !a0.areaName.length) return null
        if (!a0.region || !a0.region.length) return null
        if (!a0.country || !a0.country.length) return null
        return a0
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
                            WeatherModel.customCity = ""
                            configExpanded = false
                           WeatherModel.fetchWeather()
                        } else if (selConfigProfile === 1) {
                            if (!cityEditing) {
                                cityEditing = true
                                cityInputText = WeatherModel.customCity || ""
                            } else {
                                WeatherModel.customCity = cityInputText
                                cityEditing = false
                                configExpanded = false
                               WeatherModel.fetchWeather()
                                mainRect.forceActiveFocus()
                            }
                        }
                    } else if (selConfigItem === 1) {
                        if (selConfigProfile === 0) WeatherModel.degreeUnit = "F"
                        else if (selConfigProfile === 1) WeatherModel.degreeUnit = "C"
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
                                height: WeatherModel.dataReady ? 30 * 10 : 30

                                Column {
                                    anchors.fill: parent
                                    spacing: 10

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: cc ? WeatherCodes.icon(parseInt(cc.weatherCode)) + "  " + (WeatherModel.degreeUnit === "F" ? cc.temp_F : cc.temp_C) + "\u00b0" + WeatherModel.degreeUnit : ""
                                        color: Colors.foreground
                                        font.pixelSize: 32
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.bold: true
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: cc ? WeatherCodes.desc(parseInt(cc.weatherCode)) : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: cc ? "Feels like " + (WeatherModel.degreeUnit === "F" ? cc.FeelsLikeF : cc.FeelsLikeC) + "\u00b0" + WeatherModel.degreeUnit : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: cc ? "Humidity: " + cc.humidity + "%" : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: cc ? "Wind: " + cc.windspeedKmph + " km/h " + cc.winddir16Point : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: cc ? "UV Index: " + cc.uvIndex : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: cc ? "Pressure: " + cc.pressure + " mb" : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: cc ? "Visibility: " + cc.visibility + " km" : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: cc ? "Cloud cover: " + cc.cloudcover + "%" : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: !WeatherModel.dataReady
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
                                height: WeatherModel.dataReady ? 30 * 6 : 30

                                Column {
                                    anchors.fill: parent
                                    spacing: 10

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: WeatherModel.dataReady ? moonIcon() + "  " + moonPhase() : ""
                                        color: Colors.foreground
                                        font.pixelSize: 32
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.bold: true

                                    }

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: WeatherModel.dataReady ? "Illumination: " + moonIllumination() + "%" : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady && astro !== null
                                        text: astro ? "Moonrise: " + astro.moonrise : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady && astro !== null
                                        text: astro ? "Moonset: " + astro.moonset : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: WeatherModel.dataReady ? "Next full moon: " + nextFullMoon() : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: !WeatherModel.dataReady
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
                                height: WeatherModel.dataReady ? 30 * 3 : 30

                                Column {
                                    anchors.fill: parent
                                    spacing: 10

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: area ? area.areaName[0].value : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: area ? area.region[0].value + ", " + area.country[0].value : ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: WeatherModel.dataReady
                                        text: "Using: " + (WeatherModel.customCity || "Auto (IP)")
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        visible: !WeatherModel.dataReady
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
                                            text: "City: " + (WeatherModel.customCity || "Auto")
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
                                                        WeatherModel.customCity = ""
                                                        configExpanded = false
                                                       WeatherModel.fetchWeather()
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
                                                    WeatherModel.customCity = text
                                                    cityEditing = false
                                                    configExpanded = false
                                                   WeatherModel.fetchWeather()
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
                                                            cityInputText = WeatherModel.customCity || ""
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
                                            text: "Unit: \u00b0" + WeatherModel.degreeUnit
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
                                                        WeatherModel.degreeUnit = "F"
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
                                                        WeatherModel.degreeUnit = "C"
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
