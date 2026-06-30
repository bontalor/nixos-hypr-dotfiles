import "../../theme"
import "../../time"
import QtQuick

WidgetButton {
    // Width sized to the time string. WidgetButton owns the visible label
    // internally, so we use a hidden Text for measurement.
    width: metrics.width + 2 * Theme.margin
    label: Time.time
    panel: Panels.dateTime

    TextMetrics {
        id: metrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPixelSize
        text: Time.time
    }
}
