import "../../theme"
import "../../weather"
import QtQuick
import Quickshell

WidgetButton {
    visible: WeatherModel.dataReady
    label: WeatherModel.currentSummary
    panel: Panels.weather
}
