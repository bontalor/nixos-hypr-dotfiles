import "../theme"
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
        switch (root.selSection) {
        case 0: return WeatherModel.dataReady ? 1 : 0
        case 1: return WeatherModel.dataReady ? 1 : 0
        case 2: return WeatherModel.dataReady ? 1 : 0
        case 3: return 2
        default: return 0
        }
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
        if (root.selSection < 3) {
            y = root.headerHeight + root.colSpacing
            h = root.rowHeight
        } else if (root.configExpanded) {
            y = root.headerHeight + root.colSpacing + root.selConfigItem * (root.rowHeight + root.colSpacing) + root.rowHeight + root.selConfigProfile * 30
            h = 30
        } else {
            y = root.headerHeight + root.colSpacing + root.selConfigItem * (root.rowHeight + root.colSpacing)
            h = root.rowHeight
        }
        root.flick.scrollToVisible(y, h)
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

    onKeyPressed: function(event) {
        switch (event.key) {
        case Qt.Key_Tab:
            // Shift+Tab always means "go back", regardless of section.
            // Previously this branch was an `else if` after the
            // `selSection === 3` case, so Shift+Tab inside Configuration
            // toggled configExpanded instead of returning to the section
            // list — leaving the user stuck.
            if (event.modifiers & Qt.ShiftModifier) {
                if (root.cityEditing) {
                    root.cityEditing = false
                    root.deferredFocus()
                } else if (root.selSection === 3 && root.configExpanded) {
                    root.configExpanded = false
                } else if (root.inSection) {
                    root.inSection = false
                } else {
                    root.selSection = Math.max(root.selSection - 1, 0)
                }
            } else if (root.selSection === 3 && root.inSection) {
                if (root.configExpanded) root.configExpanded = false
                else { root.configExpanded = true; root.selConfigProfile = 0 }
            } else if (root.inSection) {
                root.selDevice = Math.min(root.selDevice + 1, Math.max(0, root.currentModelLength() - 1))
            } else {
                root.inSection = true
                root.selDevice = 0
            }
            event.accepted = true; break
        case Qt.Key_Backtab:
            if (root.selSection === 3 && root.configExpanded) root.configExpanded = false
            else if (root.inSection) root.inSection = false
            event.accepted = true; break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (root.selSection === 3 && root.inSection && root.configExpanded) {
                if (root.selConfigItem === 0) {
                    if (root.selConfigProfile === 0) {
                        WeatherModel.customCity = ""
                        root.configExpanded = false
                        WeatherModel.fetchWeather()
                    } else if (root.selConfigProfile === 1) {
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
                } else if (root.selConfigItem === 1) {
                    if (root.selConfigProfile === 0) WeatherModel.degreeUnit = "F"
                    else if (root.selConfigProfile === 1) WeatherModel.degreeUnit = "C"
                    root.configExpanded = false
                }
            } else if (root.selSection === 3 && root.inSection && !root.configExpanded) {
                root.configExpanded = true
                root.selConfigProfile = 0
            } else if (!root.inSection) {
                root.inSection = true
                root.selDevice = 0
            }
            event.accepted = true; break
        case Qt.Key_J:
        case Qt.Key_Down:
            if (root.selSection === 3 && root.configExpanded && root.inSection) {
                root.selConfigProfile = Math.min(root.selConfigProfile + 1, 1)
            } else if (root.selSection === 3 && root.inSection) {
                root.selConfigItem = Math.min(root.selConfigItem + 1, Math.max(0, 1))
            } else if (root.inSection) {
                root.selDevice = Math.min(root.selDevice + 1, Math.max(0, root.currentModelLength() - 1))
            } else {
                root.selSection = Math.min(root.selSection + 1, root.sections.length - 1)
            }
            event.accepted = true; break
        case Qt.Key_K:
        case Qt.Key_Up:
            if (root.selSection === 3 && root.configExpanded && root.inSection) {
                root.selConfigProfile = Math.max(root.selConfigProfile - 1, 0)
            } else if (root.selSection === 3 && root.inSection) {
                root.selConfigItem = Math.max(root.selConfigItem - 1, 0)
            } else if (root.inSection) {
                root.selDevice = Math.max(root.selDevice - 1, 0)
            } else {
                root.selSection = Math.max(root.selSection - 1, 0)
            }
            event.accepted = true; break
        case Qt.Key_Escape:
            if (root.cityEditing) {
                root.cityEditing = false
                root.deferredFocus()
            } else if (root.selSection === 3 && root.configExpanded) {
                root.configExpanded = false
            } else {
                root.visible = false
            }
            event.accepted = true; break
        }
    }

    // ---- Section 0: Current conditions ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 0

        Item {
            width: parent.width
            height: WeatherModel.dataReady ? 30 * 10 : 30

            Column {
                anchors.fill: parent
                spacing: 10

                Text {
                    visible: WeatherModel.dataReady
                    text: root.cc ? WeatherCodes.icon(parseInt(root.cc.weatherCode)) + " " + (WeatherModel.degreeUnit === "F" ? root.cc.temp_F : root.cc.temp_C) + "\u00b0" + WeatherModel.degreeUnit : ""
                    color: Colors.foreground
                    font.pixelSize: 32
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                Text {
                    visible: WeatherModel.dataReady
                    text: root.cc ? WeatherCodes.desc(parseInt(root.cc.weatherCode)) : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "Feels like " + (WeatherModel.degreeUnit === "F" ? root.cc.FeelsLikeF : root.cc.FeelsLikeC) + "\u00b0" + WeatherModel.degreeUnit : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "Humidity: " + root.cc.humidity + "%" : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "Wind: " + root.cc.windspeedKmph + " km/h " + root.cc.winddir16Point : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "UV Index: " + root.cc.uvIndex : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "Pressure: " + root.cc.pressure + " mb" : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "Visibility: " + root.cc.visibility + " km" : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: WeatherModel.dataReady
                    text: root.cc ? "Cloud cover: " + root.cc.cloudcover + "%" : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: !WeatherModel.dataReady
                    text: "Fetching weather data..."
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }
            }
        }
    }

    // ---- Section 1: Astronomy ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 1

        Item {
            width: parent.width
            height: WeatherModel.dataReady ? 30 * 6 : 30

            Column {
                anchors.fill: parent
                spacing: 10

                Text {
                    visible: WeatherModel.dataReady
                    text: WeatherModel.dataReady ? WeatherModel.moonIcon + " " + WeatherModel.moonPhase : ""
                    color: Colors.foreground
                    font.pixelSize: 32
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                Text {
                    visible: WeatherModel.dataReady
                    text: WeatherModel.dataReady ? "Illumination: " + WeatherModel.moonIllumination + "%" : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: WeatherModel.dataReady && root.astro !== null
                    text: root.astro ? "Moonrise: " + root.astro.moonrise : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: WeatherModel.dataReady && root.astro !== null
                    text: root.astro ? "Moonset: " + root.astro.moonset : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: WeatherModel.dataReady
                    text: WeatherModel.dataReady ? "Next full moon: " + WeatherModel.nextFullMoon : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: !WeatherModel.dataReady
                    text: "Fetching astronomy data..."
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }
            }
        }
    }

    // ---- Section 2: Location ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 2

        Item {
            width: parent.width
            height: WeatherModel.dataReady ? 30 * 3 : 30

            Column {
                anchors.fill: parent
                spacing: 10

                Text {
                    visible: WeatherModel.dataReady
                    text: root.area ? root.area.areaName[0].value : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: WeatherModel.dataReady
                    text: root.area ? root.area.region[0].value + ", " + root.area.country[0].value : ""
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: WeatherModel.dataReady
                    text: "Using: " + (WeatherModel.customCity || "Auto (IP)")
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: !WeatherModel.dataReady
                    text: "Fetching location data..."
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }
            }
        }
    }

    // ---- Section 3: Configuration ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 3

        Item {
            width: parent.width
            height: (root.configExpanded && 0 === root.selConfigItem && root.inSection)
                    ? 45 + 2 * 30
                    : 45

            Rectangle {
                anchors.fill: parent
                color: ((!root.configExpanded && root.inSection && 0 === root.selConfigItem)
                        || (root.configExpanded && root.inSection && 0 === root.selConfigItem))
                       ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
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
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.inSection) root.inSection = true
                            if (root.configExpanded && 0 === root.selConfigItem) {
                                root.configExpanded = false
                            } else {
                                root.selConfigItem = 0
                                root.configExpanded = true
                                root.selConfigProfile = 0
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    height: visible ? 2 * 30 : 0
                    visible: root.configExpanded && root.inSection && 0 === root.selConfigItem

                    Rectangle {
                        width: parent.width
                        height: 30
                        color: 0 === root.selConfigProfile
                                ? Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)
                                : Qt.alpha(Colors.base00, Theme.alphaBackground)

                        Text {
                            text: "Auto (IP)"
                            anchors { left: parent.left; leftMargin: 30; verticalCenter: parent.verticalCenter }
                            color: Colors.foreground
                            font.pixelSize: Theme.fontPixelSize
                            font.family: Theme.fontFamily
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.inSection) {
                                    WeatherModel.customCity = ""
                                    root.configExpanded = false
                                    WeatherModel.fetchWeather()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 30
                        color: !root.cityEditing && 1 === root.selConfigProfile
                                ? Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)
                                : Qt.alpha(Colors.base00, Theme.alphaBackground)

                        Text {
                            text: "Custom..."
                            anchors { left: parent.left; leftMargin: 30; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            color: Colors.foreground
                            font.pixelSize: Theme.fontPixelSize
                            font.family: Theme.fontFamily
                            visible: !root.cityEditing
                        }

                        TextInput {
                            visible: root.cityEditing
                            anchors { left: parent.left; leftMargin: 30; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
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
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.inSection && !root.cityEditing) {
                                    root.cityEditing = true
                                    root.cityInputText = WeatherModel.customCity || ""
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: (root.configExpanded && 1 === root.selConfigItem && root.inSection)
                    ? 45 + 2 * 30
                    : 45

            Rectangle {
                anchors.fill: parent
                color: ((!root.configExpanded && root.inSection && 1 === root.selConfigItem)
                        || (root.configExpanded && root.inSection && 1 === root.selConfigItem))
                       ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
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
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.inSection) root.inSection = true
                            if (root.configExpanded && 1 === root.selConfigItem) {
                                root.configExpanded = false
                            } else {
                                root.selConfigItem = 1
                                root.configExpanded = true
                                root.selConfigProfile = 0
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    height: visible ? 2 * 30 : 0
                    visible: root.configExpanded && root.inSection && 1 === root.selConfigItem

                    Rectangle {
                        width: parent.width
                        height: 30
                        color: 0 === root.selConfigProfile
                                ? Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)
                                : Qt.alpha(Colors.base00, Theme.alphaBackground)

                        Text {
                            text: "Fahrenheit"
                            anchors { left: parent.left; leftMargin: 30; verticalCenter: parent.verticalCenter }
                            color: Colors.foreground
                            font.pixelSize: Theme.fontPixelSize
                            font.family: Theme.fontFamily
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.inSection) {
                                    WeatherModel.degreeUnit = "F"
                                    root.configExpanded = false
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 30
                        color: 1 === root.selConfigProfile
                                ? Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)
                                : Qt.alpha(Colors.base00, Theme.alphaBackground)

                        Text {
                            text: "Celsius"
                            anchors { left: parent.left; leftMargin: 30; verticalCenter: parent.verticalCenter }
                            color: Colors.foreground
                            font.pixelSize: Theme.fontPixelSize
                            font.family: Theme.fontFamily
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.inSection) {
                                    WeatherModel.degreeUnit = "C"
                                    root.configExpanded = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
