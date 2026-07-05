import "../theme"
import "../components"
import "../util"
import "."
import QtQuick

Panel {
    id: root
    title: "Weather"
    sections: [
        { name: "Weather" },
        { name: "Forecast" },
        { name: "Astronomy" },
        { name: "Location" }
    ]

    // --- Named section indices (replace magic numbers) ---
    readonly property int secWeather: 0
    readonly property int secForecast: 1
    readonly property int secAstronomy: 2
    readonly property int secLocation: 3

    // Unit and city live in the Settings panel (Weather group) —
    // WeatherModel binds to the prefs and refetches on a city change.
    // All units follow the temperature pref: °F implies mph/inHg/miles
    // (wttr.in ships both unit systems in every payload, so no math).
    readonly property bool imperial: WeatherModel.degreeUnit === "F"

    // Forecast day rows expand to variable heights, so the base panel's
    // fixed-stride auto-scroll doesn't apply; the content fits the
    // Flickable without scrolling anyway.
    autoScroll: false

    // wttr.in's j1 payload always carries a 3-day `weather` array —
    // fetched since day one for astronomy, now shown as a forecast.
    readonly property var days: WeatherModel.dataReady && WeatherModel.weatherData.weather
        ? WeatherModel.weatherData.weather : []

    // Day row (0-based) currently expanded to its hourly entries, or -1.
    property int expandedDay: -1
    onSectionChanged: root.expandedDay = -1

    currentModelLength: function() {
        return root.selSection === root.secForecast
            ? root.days.length
            : (WeatherModel.dataReady ? 1 : 0)
    }

    onDeviceActivated: function(idx) {
        if (root.selSection === root.secForecast)
            root.expandedDay = root.expandedDay === idx ? -1 : idx
    }

    onShown: {
        WeatherModel.fetchWeather()
        root.expandedDay = -1
    }

    function dayName(i, dateStr) {
        if (i === 0) return "Today"
        if (i === 1) return "Tomorrow"
        var p = dateStr.split("-")
        return Qt.formatDateTime(new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2])), "dddd")
    }

    // Peak rain probability across the day's hourly entries.
    function rainChance(day) {
        var h = day.hourly || []
        var m = 0
        for (var i = 0; i < h.length; i++)
            m = Math.max(m, parseInt(h[i].chanceofrain) || 0)
        return m
    }

    // Representative icon: midday entry (hourly is 3-hour steps, 4 = 12:00).
    function dayIcon(day) {
        var h = day.hourly || []
        var e = h[4] || h[0]
        return e ? WeatherCodes.icon(e.weatherCode) : ""
    }

    function temp(entry, maxKey) {
        return WeatherModel.degreeUnit === "F" ? entry[maxKey + "F"] : entry[maxKey + "C"]
    }

    // Hourly `time` is "0" / "300" / ... / "2100".
    function fmtHour(t) {
        var h = Math.floor((parseInt(t) || 0) / 100)
        if (PrefStore.timeFormat === "24h") return FormatUtil.zeroPad(h) + ":00"
        var h12 = h % 12 === 0 ? 12 : h % 12
        return h12 + (h < 12 ? " AM" : " PM")
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

    // ---- Section 0: Current conditions ----
    Column {
        width: parent.width
        spacing: Theme.margin
        visible: root.selSection === root.secWeather

        Column {
            width: parent.width
            spacing: Theme.margin
            visible: WeatherModel.dataReady

            ThemeText {
                text: WeatherModel.currentSummary
                font.pixelSize: 32
                font.bold: true
            }

            ThemeText { text: root.cc ? WeatherCodes.desc(root.cc.weatherCode) : "" }
            ThemeText { text: root.cc ? "Feels like " + (root.imperial ? root.cc.FeelsLikeF : root.cc.FeelsLikeC) + "°" + WeatherModel.degreeUnit : "" }
            ThemeText { text: root.cc ? "Humidity: " + root.cc.humidity + "%" : "" }
            ThemeText { text: root.cc ? "Wind: " + (root.imperial ? root.cc.windspeedMiles + " mph " : root.cc.windspeedKmph + " km/h ") + root.cc.winddir16Point : "" }
            ThemeText { text: root.cc ? "UV Index: " + root.cc.uvIndex : "" }
            ThemeText { text: root.cc ? "Pressure: " + (root.imperial ? root.cc.pressureInches + " inHg" : root.cc.pressure + " mb") : "" }
            ThemeText { text: root.cc ? "Visibility: " + (root.imperial ? root.cc.visibilityMiles + " mi" : root.cc.visibility + " km") : "" }
            ThemeText { text: root.cc ? "Cloud cover: " + root.cc.cloudcover + "%" : "" }
        }

        ThemeText {
            visible: !WeatherModel.dataReady
            text: WeatherModel.fetchError ? "Fetch failed: " + WeatherModel.fetchError : "Fetching weather data..."
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
        }
    }

    // ---- Section 1: Forecast ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secForecast

        Repeater {
            model: root.days

            delegate: PanelRow {
                id: dayRow
                property var day: modelData
                property bool expanded: index === root.expandedDay

                width: parent.width
                height: root.rowHeight + (expanded ? hourlyCol.height : 0)
                selected: root.inSection && index === root.selDevice
                panel: root
                itemIndex: index
                onClicked: root.expandedDay = dayRow.expanded ? -1 : index

                Item {
                    width: parent.width
                    height: root.rowHeight

                    ThemeText {
                        text: root.dayName(index, dayRow.day.date)
                        anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                        font.bold: dayRow.expanded
                        width: parent.width * 0.35
                        elide: Text.ElideRight
                    }

                    ThemeText {
                        anchors.centerIn: parent
                        text: root.dayIcon(dayRow.day) + "  "
                              + root.temp(dayRow.day, "maxtemp") + "° / "
                              + root.temp(dayRow.day, "mintemp") + "°"
                    }

                    ThemeText {
                        text: root.rainChance(dayRow.day) + "% rain"
                        anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                        color: Qt.alpha(Colors.foreground, Theme.alphaDim)
                    }
                }

                Column {
                    id: hourlyCol
                    anchors.top: parent.top
                    anchors.topMargin: root.rowHeight
                    width: parent.width
                    visible: dayRow.expanded
                    height: dayRow.expanded && dayRow.day.hourly
                            ? dayRow.day.hourly.length * Theme.searchRowHeight : 0

                    Repeater {
                        model: dayRow.expanded ? dayRow.day.hourly : []

                        delegate: Item {
                            width: parent.width
                            height: Theme.searchRowHeight

                            ThemeText {
                                text: root.fmtHour(modelData.time)
                                anchors { left: parent.left; leftMargin: 3 * Theme.margin; verticalCenter: parent.verticalCenter }
                                color: Qt.alpha(Colors.foreground, Theme.alphaDim)
                            }

                            ThemeText {
                                anchors.centerIn: parent
                                text: WeatherCodes.icon(modelData.weatherCode) + "  "
                                      + root.temp(modelData, "temp") + "°"
                            }

                            ThemeText {
                                text: (parseInt(modelData.chanceofrain) || 0) + "%"
                                anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                                color: Qt.alpha(Colors.foreground, Theme.alphaDim)
                            }
                        }
                    }
                }
            }
        }

        EmptyLabel {
            visible: root.days.length === 0
            text: WeatherModel.dataReady ? "No forecast data" : "Fetching weather data..."
        }
    }

    // ---- Section 2: Astronomy ----
    Column {
        width: parent.width
        spacing: Theme.margin
        visible: root.selSection === root.secAstronomy

        Column {
            width: parent.width
            spacing: Theme.margin
            visible: WeatherModel.dataReady

            ThemeText {
                text: WeatherModel.moonIcon + " " + WeatherModel.moonPhase
                font.pixelSize: 32
                font.bold: true
            }

            ThemeText { text: "Illumination: " + WeatherModel.moonIllumination + "%" }

            ThemeText {
                visible: root.astro !== null
                text: root.astro ? "Moonrise: " + root.astro.moonrise : ""
            }

            ThemeText {
                visible: root.astro !== null
                text: root.astro ? "Moonset: " + root.astro.moonset : ""
            }

            ThemeText { text: "Next full moon: " + WeatherModel.nextFullMoon }
        }

        ThemeText {
            visible: !WeatherModel.dataReady
            text: "Fetching astronomy data..."
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
        }
    }

    // ---- Section 3: Location ----
    Column {
        width: parent.width
        spacing: Theme.margin
        visible: root.selSection === root.secLocation

        Column {
            width: parent.width
            spacing: Theme.margin
            visible: WeatherModel.dataReady

            ThemeText { text: root.area ? root.area.areaName[0].value : "" }
            ThemeText { text: root.area ? root.area.region[0].value + ", " + root.area.country[0].value : "" }
            ThemeText { text: "Using: " + (WeatherModel.customCity || "Auto (IP)") }
        }

        ThemeText {
            visible: !WeatherModel.dataReady
            text: "Fetching location data..."
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
        }
    }

}
