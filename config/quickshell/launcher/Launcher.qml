import "../theme"
import "."
import QtQuick
import Quickshell
import Quickshell.Widgets

SearchPanel {
    id: root
    title: "App Launcher"

    property var allApps: []

    Component.onCompleted: rebuildApps()
    Timer { id: rebuildDebounce; interval: 50; onTriggered: rebuildApps() }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { rebuildDebounce.restart() }
    }

    function rebuildApps() {
        allApps = [...DesktopEntries.applications.values]
            .filter(a => a.name)
            .sort((a, b) => a.name.localeCompare(b.name))
    }

    items: root.allApps
    matchPredicate: function(item, q) {
        if (!item) return false
        return item.name.toLowerCase().includes(q)
            || (item.genericName || "").toLowerCase().includes(q)
            || (item.comment || "").toLowerCase().includes(q)
    }

    onLaunched: function(idx) {
        var app = root.filtered[idx]
        if (!app) return
        Quickshell.execDetached({
            command: app.command,
            workingDirectory: app.workingDirectory,
            environment: ({ "XDG_CURRENT_DESKTOP": "Hyprland" })
        })
        root.visible = false
    }

    rowDelegate: SearchRow {
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            source: modelData?.icon ? Quickshell.iconPath(modelData.icon, false) : ""
            width: Theme.iconSize
            height: Theme.iconSize
            visible: source.toString() !== ""
        }
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData?.name ?? ""
        }
    }
}