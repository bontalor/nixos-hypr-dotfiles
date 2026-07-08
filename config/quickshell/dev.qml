// Single-panel dev harness — iterate on one panel without running the
// whole shell (bar, popups, daemons):
//
//   LOR_PANEL=weather qs -p dev.qml
//
// LOR_PANEL is a Panels registry key (components/Panels.qml); defaults to
// the launcher. Only the requested panel is instantiated (so e.g. the
// notifications panel's NotificationServer only spins up when actually
// under test), forced visible, and the process exits when its window
// closes (Escape). panelKey stays unset — nothing registers.

import "./components"
import QtQuick
import Quickshell

ShellRoot {
    id: root

    property string which: (Quickshell.env("LOR_PANEL") || "launcher").toLowerCase()

    PanelComponents { id: shared }

    Loader {
        sourceComponent: shared.get(root.which) ?? shared.launcher
        onItemChanged: if (item) item.visible = true
    }

    Connections {
        target: Quickshell
        function onLastWindowClosed() { Qt.quit() }
    }
}
