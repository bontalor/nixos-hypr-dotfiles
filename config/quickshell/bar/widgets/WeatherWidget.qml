import "../../theme"
import "../../weather"
import QtQuick
import Quickshell
import Quickshell.Io

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
            ? WeatherCodes.icon(parseInt(WeatherModel.weatherData.current_condition[0].weatherCode)) + " " + (WeatherModel.degreeUnit === "F" ? WeatherModel.weatherData.current_condition[0].temp_F : WeatherModel.weatherData.current_condition[0].temp_C) + "\u00b0" + WeatherModel.degreeUnit
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
