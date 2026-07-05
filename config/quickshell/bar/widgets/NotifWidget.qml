import "../../theme"
import "../../components"
import "../../util"
import "../../notifications"
import QtQuick

WidgetButton {
    // Muted-bell prefix while do-not-disturb is on (popups suppressed;
    // critical ones still pop, history records everything).
    label: (PrefStore.notifPopups ? "" : Icon.bellMuted + " ")
           + "(" + NotifDaemon.history.count + ")"
    panel: Panels.notifications
    acceptRightClick: true
    onRightClicked: PrefStore.notifPopups = !PrefStore.notifPopups
}
