import "../../theme"
import "../../notifications"
import QtQuick

WidgetButton {
    label: "(" + NotifDaemon.history.count + ")"
    panel: Panels.notifications
}
