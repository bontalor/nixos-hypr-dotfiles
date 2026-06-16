import QtQuick
import Quickshell
import Quickshell.Io

Scope {

    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
            notifyProc.command = ["notify-send", "Quickshell", "Config reloaded", "-i", "dialog-information"]
            notifyProc.running = true
        }
    }

    Process {
        id: notifyProc
        running: false
    }
}
