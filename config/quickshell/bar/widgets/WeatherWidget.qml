import "../../theme"
import "../../weather"
import QtQuick
import Quickshell

Item {
    id: root
    width: weatherText.width + 20
    height: 30
    visible: WeatherModel.dataReady

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
    }

    Text {
        id: weatherText
        anchors.centerIn: parent
        text: WeatherModel.dataReady
            ? (WeatherModel.isNight ? WeatherModel.moonIcon + " " : "") + WeatherCodes.icon(parseInt(WeatherModel.weatherData.current_condition[0].weatherCode)) + " " + (WeatherModel.degreeUnit === "F" ? WeatherModel.weatherData.current_condition[0].temp_F : WeatherModel.weatherData.current_condition[0].temp_C) + "\u00b0" + WeatherModel.degreeUnit
            : ""
        font.pixelSize: Theme.fontPixelSize
        font.family: Theme.fontFamily
        color: Colors.foreground
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("weather")
    }
}
