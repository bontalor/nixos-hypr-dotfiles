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
        // Desktop applications plus one synthetic entry per shell panel
        // (Panels.launcherEntries), so every panel is searchable here.
        allApps = [...DesktopEntries.applications.values]
            .filter(a => a.name)
            .concat(Panels.launcherEntries)
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
        if (app.panelKey) {
            // toggle() shows the target panel and hides every other
            // registered panel — including this launcher.
            Panels.toggle(app.panelKey)
            return
        }
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
            // Panel entries get the Quickshell logo (copied into assets/
            // from the package's org.quickshell.svg — not resolvable via
            // iconPath, it isn't installed into the system icon theme).
            source: modelData?.panelKey
                ? "file://" + Quickshell.shellDir + "/assets/quickshell-logo.svg"
                : modelData?.icon ? Quickshell.iconPath(modelData.icon, false) : ""
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