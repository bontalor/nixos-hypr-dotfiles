import "../theme"
import "."
import QtQuick

Panel {
    id: root
    title: "Weather"
    sections: [
        { name: "Weather" },
        { name: "Astronomy" },
        { name: "Location" },
        { name: "Configuration" }
    ]

    // --- Named section/config indices (replace magic numbers) ---
    readonly property int secWeather: 0
    readonly property int secAstronomy: 1
    readonly property int secLocation: 2
    readonly property int secConfig: 3

    readonly property int cfgItemCity: 0
    readonly property int cfgItemUnit: 1
    readonly property int maxConfigProfiles: 2

    // Panel's expandable-config mode drives all keyboard navigation for
    // the Configuration section. Only the inline city TextInput flow
    // (cityEditing) is panel-specific.
    expandSection: secConfig
    configItemCount: function() { return 2 }
    configProfileCount: function() { return root.maxConfigProfiles }
    configCurrentProfile: function() {
        if (root.selConfigItem === root.cfgItemCity)
            return WeatherModel.customCity ? 1 : 0
        return WeatherModel.degreeUnit === "F" ? 0 : 1
    }
    onConfigActivated: root.activateConfigItem()

    currentModelLength: function() { return WeatherModel.dataReady ? 1 : 0 }

    property bool cityEditing: false
    property string cityInputText: ""

    // Deferred-focus helper for after the city-input flow dismisses the
    // keyboard focus. Qt.callLater is the event-loop-friendly alternative
    // to the previous zero-interval Timer workaround.
    function deferredFocus() { Qt.callLater(root.forceFocus) }

    onShown: {
        WeatherModel.fetchWeather()
        root.cityEditing = false
    }

    // The dropdown collapsing (section switch, Escape, activation) always
    // ends any in-progress city edit — otherwise the TextInput reappears
    // in edit mode when the dropdown next opens.
    onConfigExpandedChanged: if (!configExpanded) root.cityEditing = false

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

    function activateConfigItem() {
        if (root.selConfigItem === root.cfgItemCity) {
            if (root.selConfigProfile === 0) {
                WeatherModel.customCity = ""
                root.configExpanded = false
                WeatherModel.fetchWeather()
            } else {
                if (!root.cityEditing) {
                    root.cityEditing = true
                    root.cityInputText = WeatherModel.customCity || ""
                } else {
                    WeatherModel.customCity = root.cityInputText
                    root.cityEditing = false
                    root.configExpanded = false
                    WeatherModel.fetchWeather()
                    root.deferredFocus()
                }
            }
        } else {
            // cfgItemUnit
            WeatherModel.degreeUnit = root.selConfigProfile === 0 ? "F" : "C"
            root.configExpanded = false
        }
    }

    // Escape / Shift+Tab back out of the city-editing flow before the
    // default handler collapses anything. Runs before Panel.handleKey;
    // accepting the event pre-empts it.
    onKeyPressed: function(event) {
        if (!root.cityEditing) return
        if (event.key === Qt.Key_Escape
            || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))
            || event.key === Qt.Key_Backtab) {
            root.cityEditing = false
            root.deferredFocus()
            event.accepted = true
        }
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
            ThemeText { text: root.cc ? "Feels like " + (WeatherModel.degreeUnit === "F" ? root.cc.FeelsLikeF : root.cc.FeelsLikeC) + "°" + WeatherModel.degreeUnit : "" }
            ThemeText { text: root.cc ? "Humidity: " + root.cc.humidity + "%" : "" }
            ThemeText { text: root.cc ? "Wind: " + root.cc.windspeedKmph + " km/h " + root.cc.winddir16Point : "" }
            ThemeText { text: root.cc ? "UV Index: " + root.cc.uvIndex : "" }
            ThemeText { text: root.cc ? "Pressure: " + root.cc.pressure + " mb" : "" }
            ThemeText { text: root.cc ? "Visibility: " + root.cc.visibility + " km" : "" }
            ThemeText { text: root.cc ? "Cloud cover: " + root.cc.cloudcover + "%" : "" }
        }

        ThemeText {
            visible: !WeatherModel.dataReady
            text: WeatherModel.fetchError ? "Fetch failed: " + WeatherModel.fetchError : "Fetching weather data..."
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
        }
    }

    // ---- Section 1: Astronomy ----
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

    // ---- Section 2: Location ----
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

    // ---- Section 3: Configuration ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secConfig

        ConfigExpandItem {
            label: "City: " + (WeatherModel.customCity || "Auto")
            isSelected: root.inSection && root.cfgItemCity === root.selConfigItem
            isExpanded: root.configExpanded && root.cfgItemCity === root.selConfigItem
            profileCount: root.maxConfigProfiles
            panel: root
            itemIndex: root.cfgItemCity

            ConfigProfileRow {
                label: "Auto (IP)"
                isSelected: 0 === root.selConfigProfile
                onClicked: {
                    if (root.inSection) { root.selConfigProfile = 0; root.activateConfigItem() }
                }
            }

            ConfigProfileRow {
                label: root.cityEditing ? "" : "Custom..."
                isSelected: !root.cityEditing && 1 === root.selConfigProfile
                onClicked: {
                    if (root.inSection && !root.cityEditing) {
                        root.selConfigProfile = 1
                        root.cityEditing = true
                        root.cityInputText = WeatherModel.customCity || ""
                    }
                }

                TextInput {
                    visible: root.cityEditing
                    anchors { left: parent.left; leftMargin: 3 * Theme.margin; right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    text: root.cityInputText
                    focus: root.cityEditing
                    onAccepted: {
                        WeatherModel.customCity = text
                        root.cityEditing = false
                        root.configExpanded = false
                        WeatherModel.fetchWeather()
                        root.deferredFocus()
                    }
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            root.cityEditing = false
                            root.deferredFocus()
                            event.accepted = true
                        }
                    }
                }
            }
        }

        ConfigExpandItem {
            label: "Unit: °" + WeatherModel.degreeUnit
            isSelected: root.inSection && root.cfgItemUnit === root.selConfigItem
            isExpanded: root.configExpanded && root.cfgItemUnit === root.selConfigItem
            profileCount: root.maxConfigProfiles
            panel: root
            itemIndex: root.cfgItemUnit

            ConfigProfileRow {
                label: "Fahrenheit"
                isSelected: 0 === root.selConfigProfile
                onClicked: {
                    if (root.inSection) { root.selConfigProfile = 0; root.activateConfigItem() }
                }
            }

            ConfigProfileRow {
                label: "Celsius"
                isSelected: 1 === root.selConfigProfile
                onClicked: {
                    if (root.inSection) { root.selConfigProfile = 1; root.activateConfigItem() }
                }
            }
        }
    }
}
