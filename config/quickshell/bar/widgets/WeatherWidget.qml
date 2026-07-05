import "../../theme"
import "../../components"
import "../../weather"
import QtQuick
import Quickshell

WidgetButton {
    // A failed fetch shows an alert glyph instead of hiding the chip —
    // clicking through to the panel reveals the error detail. Before the
    // first fetch resolves either way, the chip stays hidden.
    visible: WeatherModel.dataReady || WeatherModel.fetchError !== ""
    label: WeatherModel.dataReady ? WeatherModel.currentSummary : Icon.alert
    panel: Panels.weather
}
