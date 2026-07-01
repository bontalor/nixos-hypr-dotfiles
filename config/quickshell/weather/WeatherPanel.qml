import "../theme"
import "../util"
import "."
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Panel {
    id: root
    title: "Weather"
    sections: [
        { name: "Weather" },
        { name: "Astronomy" },
        { name: "Location" },
        { name: "Configuration" }
    ]

    useDefaultKeys: false
    autoScroll: false

    // --- Named section/config indices (replace magic numbers) ---
    readonly property int secWeather: 0
    readonly property int secAstronomy: 1
    readonly property int secLocation: 2
    readonly property int secConfig: 3

    readonly property int cfgItemCity: 0
    readonly property int cfgItemUnit: 1
    readonly property int maxConfigProfiles: 2

    property bool configExpanded: false
    property int selConfigItem: 0
    property int selConfigProfile: 0

    property bool cityEditing: false
    property string cityInputText: ""

    // Deferred-focus helper for after the city-input flow dismisses the
    // keyboard focus. Qt.callLater is the event-loop-friendly alternative
    // to the previous zero-interval Timer workaround.
    function deferredFocus() { Qt.callLater(root.forceFocus) }

    function currentModelLength() {
        if (root.selSection === root.secConfig) return 2
        return WeatherModel.dataReady ? 1 : 0
    }

    onShown: {
        WeatherModel.fetchWeather()
        root.configExpanded = false
        root.cityEditing = false
    }

    onSelDeviceChanged: root.scrollSelectionIntoView()
    onSelConfigItemChanged: root.scrollSelectionIntoView()
    onSelConfigProfileChanged: root.scrollSelectionIntoView()
    onInSectionChanged: if (root.inSection) root.scrollSelectionIntoView()
    onConfigExpandedChanged: if (root.inSection && root.configExpanded) root.scrollSelectionIntoView()

    function scrollSelectionIntoView() {
        if (!root.inSection) return
        var y, h
        if (root.selSection < root.secConfig) {
            y = root.headerHeight + root.colSpacing
            h = root.rowHeight
        } else if (root.configExpanded) {
            y = root.headerHeight + root.colSpacing
              + root.selConfigItem * (root.rowHeight + root.colSpacing)
              + root.rowHeight + root.selConfigProfile * Theme.searchRowHeight
            h = Theme.searchRowHeight
        } else {
            y = root.headerHeight + root.colSpacing
              + root.selConfigItem * (root.rowHeight + root.colSpacing)
            h = root.rowHeight
        }
        root.scrollToVisible(y, h)
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

    // --- Navigation helpers (collapse the prior 100-line state machine) ---

    function navDown() {
        if (root.selSection === root.secConfig && root.configExpanded && root.inSection) {
            root.selConfigProfile = Scroll.clamp(root.selConfigProfile + 1, 0, root.maxConfigProfiles - 1)
        } else if (root.selSection === root.secConfig && root.inSection) {
            root.selConfigItem = Scroll.clamp(root.selConfigItem + 1, 0, 1)
        } else if (root.inSection) {
            root.selDevice = Scroll.step(root.selDevice, 1, root.currentModelLength())
        } else {
            root.selSection = Scroll.clamp(root.selSection + 1, 0, root.sections.length - 1)
        }
    }

    function navUp() {
        if (root.selSection === root.secConfig && root.configExpanded && root.inSection) {
            root.selConfigProfile = Scroll.clamp(root.selConfigProfile - 1, 0, root.maxConfigProfiles - 1)
        } else if (root.selSection === root.secConfig && root.inSection) {
            root.selConfigItem = Scroll.clamp(root.selConfigItem - 1, 0, 1)
        } else if (root.inSection) {
            root.selDevice = Scroll.step(root.selDevice, -1, root.currentModelLength())
        } else {
            root.selSection = Scroll.clamp(root.selSection - 1, 0, root.sections.length - 1)
        }
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

    onKeyPressed: function(event) {
        switch (event.key) {
        case Qt.Key_Tab:
            if (event.modifiers & Qt.ShiftModifier) {
                if (root.cityEditing) { root.cityEditing = false; root.deferredFocus() }
                else if (root.selSection === root.secConfig && root.configExpanded) root.configExpanded = false
                else if (root.inSection) root.inSection = false
                else root.selSection = Scroll.clamp(root.selSection - 1, 0, root.sections.length - 1)
            } else if (root.selSection === root.secConfig && root.inSection) {
                if (root.configExpanded) root.configExpanded = false
                else { root.configExpanded = true; root.selConfigProfile = 0 }
            } else if (root.inSection) {
                root.selDevice = Scroll.step(root.selDevice, 1, root.currentModelLength())
            } else {
                root.inSection = true; root.selDevice = 0
            }
            event.accepted = true; break
        case Qt.Key_Backtab:
            if (root.selSection === root.secConfig && root.configExpanded) root.configExpanded = false
            else if (root.inSection) root.inSection = false
            event.accepted = true; break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (root.selSection === root.secConfig && root.inSection && root.configExpanded) {
                root.activateConfigItem()
            } else if (root.selSection === root.secConfig && root.inSection && !root.configExpanded) {
                root.configExpanded = true; root.selConfigProfile = 0
            } else if (!root.inSection) {
                root.inSection = true; root.selDevice = 0
            }
            event.accepted = true; break
        case Qt.Key_J:
        case Qt.Key_Down:
            root.navDown(); event.accepted = true; break
        case Qt.Key_K:
        case Qt.Key_Up:
            root.navUp(); event.accepted = true; break
        case Qt.Key_Escape:
            if (root.cityEditing) { root.cityEditing = false; root.deferredFocus() }
            else if (root.selSection === root.secConfig && root.configExpanded) root.configExpanded = false
            else root.visible = false
            event.accepted = true; break
        }
    }

    // ---- Section 0: Current conditions ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secWeather

        // Height derived from content count, not a magic `30 * 10`.
        Item {
            width: parent.width
            height: WeatherModel.dataReady ? 10 * (Theme.fontPixelSize + Theme.margin) : Theme.searchRowHeight

            Column {
                anchors.fill: parent
                spacing: Theme.margin

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: WeatherModel.currentSummary
                    font.pixelSize: 32
                    font.bold: true
                }

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: root.cc ? WeatherCodes.desc(root.cc.weatherCode) : ""
                }

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "Feels like " + (WeatherModel.degreeUnit === "F" ? root.cc.FeelsLikeF : root.cc.FeelsLikeC) + "\u00b0" + WeatherModel.degreeUnit : ""
                }

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "Humidity: " + root.cc.humidity + "%" : ""
                }

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "Wind: " + root.cc.windspeedKmph + " km/h " + root.cc.winddir16Point : ""
                }

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "UV Index: " + root.cc.uvIndex : ""
                }

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "Pressure: " + root.cc.pressure + " mb" : ""
                }

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "Visibility: " + root.cc.visibility + " km" : ""
                }

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "Cloud cover: " + root.cc.cloudcover + "%" : ""
                }

                ThemeText {
                    visible: !WeatherModel.dataReady
                    text: WeatherModel.fetchError ? "Fetch failed: " + WeatherModel.fetchError : "Fetching weather data..."
                    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                }
            }
        }
    }

    // ---- Section 1: Astronomy ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secAstronomy

        Item {
            width: parent.width
            height: WeatherModel.dataReady ? 6 * (Theme.fontPixelSize + Theme.margin) : Theme.searchRowHeight

            Column {
                anchors.fill: parent
                spacing: Theme.margin

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: WeatherModel.dataReady ? WeatherModel.moonIcon + " " + WeatherModel.moonPhase : ""
                    font.pixelSize: 32
                    font.bold: true
                }

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: WeatherModel.dataReady ? "Illumination: " + WeatherModel.moonIllumination + "%" : ""
                }

                ThemeText {
                    visible: WeatherModel.dataReady && root.astro !== null
                    text: root.astro ? "Moonrise: " + root.astro.moonrise : ""
                }

                ThemeText {
                    visible: WeatherModel.dataReady && root.astro !== null
                    text: root.astro ? "Moonset: " + root.astro.moonset : ""
                }

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: WeatherModel.dataReady ? "Next full moon: " + WeatherModel.nextFullMoon : ""
                }

                ThemeText {
                    visible: !WeatherModel.dataReady
                    text: "Fetching astronomy data..."
                    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                }
            }
        }
    }

    // ---- Section 2: Location ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secLocation

        Item {
            width: parent.width
            height: WeatherModel.dataReady ? 3 * (Theme.fontPixelSize + Theme.margin) : Theme.searchRowHeight

            Column {
                anchors.fill: parent
                spacing: Theme.margin

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: root.area ? root.area.areaName[0].value : ""
                }

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: root.area ? root.area.region[0].value + ", " + root.area.country[0].value : ""
                }

                ThemeText {
                    visible: WeatherModel.dataReady
                    text: "Using: " + (WeatherModel.customCity || "Auto (IP)")
                }

                ThemeText {
                    visible: !WeatherModel.dataReady
                    text: "Fetching location data..."
                    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                }
            }
        }
    }

    // ---- Section 3: Configuration ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secConfig

        // --- Config item: City ---
        Item {
            width: parent.width
            height: (root.configExpanded && root.cfgItemCity === root.selConfigItem && root.inSection)
                    ? root.rowHeight + root.maxConfigProfiles * Theme.searchRowHeight
                    : root.rowHeight

            Rectangle {
                anchors.fill: parent
                // Simplified: the prior (!configExpanded || configExpanded)
                // OR collapsed to just `inSection && selConfigItem match`.
                color: (root.inSection && root.cfgItemCity === root.selConfigItem) || cityMouse.containsMouse
                       ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
            }

            Column {
                width: parent.width

                Item {
                    width: parent.width
                    height: root.rowHeight

                    ThemeText {
                        text: "City: " + (WeatherModel.customCity || "Auto")
                        anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        id: cityMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.inSection) root.inSection = true
                            if (root.configExpanded && root.cfgItemCity === root.selConfigItem) {
                                root.configExpanded = false
                            } else {
                                root.selConfigItem = root.cfgItemCity
                                root.configExpanded = true
                                root.selConfigProfile = 0
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    height: visible ? root.maxConfigProfiles * Theme.searchRowHeight : 0
                    visible: root.configExpanded && root.inSection && root.cfgItemCity === root.selConfigItem

                    Rectangle {
                        width: parent.width
                        height: Theme.searchRowHeight
                        color: 0 === root.selConfigProfile
                                ? Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)
                                : cityAutoMouse.containsMouse
                                    ? Qt.alpha(Colors.base01, Theme.alphaSelected)
                                    : Qt.alpha(Colors.base00, Theme.alphaBackground)

                        ThemeText {
                            text: "Auto (IP)"
                            anchors { left: parent.left; leftMargin: 3 * Theme.margin; verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            id: cityAutoMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.inSection) root.activateConfigItem()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Theme.searchRowHeight
                        color: !root.cityEditing && 1 === root.selConfigProfile
                                ? Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)
                                : cityCustomMouse.containsMouse
                                    ? Qt.alpha(Colors.base01, Theme.alphaSelected)
                                    : Qt.alpha(Colors.base00, Theme.alphaBackground)

                        ThemeText {
                            text: "Custom..."
                            anchors { left: parent.left; leftMargin: 3 * Theme.margin; right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                            visible: !root.cityEditing
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

                        MouseArea {
                            id: cityCustomMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.inSection && !root.cityEditing) {
                                    root.selConfigProfile = 1
                                    root.cityEditing = true
                                    root.cityInputText = WeatherModel.customCity || ""
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Config item: Unit ---
        Item {
            width: parent.width
            height: (root.configExpanded && root.cfgItemUnit === root.selConfigItem && root.inSection)
                    ? root.rowHeight + root.maxConfigProfiles * Theme.searchRowHeight
                    : root.rowHeight

            Rectangle {
                anchors.fill: parent
                color: (root.inSection && root.cfgItemUnit === root.selConfigItem) || unitMouse.containsMouse
                       ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
            }

            Column {
                width: parent.width

                Item {
                    width: parent.width
                    height: root.rowHeight

                    ThemeText {
                        text: "Unit: \u00b0" + WeatherModel.degreeUnit
                        anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        id: unitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.inSection) root.inSection = true
                            if (root.configExpanded && root.cfgItemUnit === root.selConfigItem) {
                                root.configExpanded = false
                            } else {
                                root.selConfigItem = root.cfgItemUnit
                                root.configExpanded = true
                                root.selConfigProfile = 0
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    height: visible ? root.maxConfigProfiles * Theme.searchRowHeight : 0
                    visible: root.configExpanded && root.inSection && root.cfgItemUnit === root.selConfigItem

                    Rectangle {
                        width: parent.width
                        height: Theme.searchRowHeight
                        color: 0 === root.selConfigProfile
                                ? Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)
                                : unitFMouse.containsMouse
                                    ? Qt.alpha(Colors.base01, Theme.alphaSelected)
                                    : Qt.alpha(Colors.base00, Theme.alphaBackground)

                        ThemeText {
                            text: "Fahrenheit"
                            anchors { left: parent.left; leftMargin: 3 * Theme.margin; verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            id: unitFMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.inSection) {
                                    root.selConfigProfile = 0
                                    root.activateConfigItem()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Theme.searchRowHeight
                        color: 1 === root.selConfigProfile
                                ? Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)
                                : unitCMouse.containsMouse
                                    ? Qt.alpha(Colors.base01, Theme.alphaSelected)
                                    : Qt.alpha(Colors.base00, Theme.alphaBackground)

                        ThemeText {
                            text: "Celsius"
                            anchors { left: parent.left; leftMargin: 3 * Theme.margin; verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            id: unitCMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.inSection) {
                                    root.selConfigProfile = 1
                                    root.activateConfigItem()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
