pragma ComponentBehavior: Bound

import "../theme"
import "../components"
import "."
import QtQuick
import Quickshell
import Quickshell.Widgets

SearchPanel {
    id: root
    title: "App Launcher"

    property var allApps: []

    Component.onCompleted: rebuildApps()
    Timer { id: rebuildDebounce; interval: 50; onTriggered: root.rebuildApps() }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { rebuildDebounce.restart() }
    }
    // Panel entries trickle in as each panel registers during startup;
    // the debounce collapses those into one rebuild.
    Connections {
        target: Panels
        function onLauncherEntriesChanged() { rebuildDebounce.restart() }
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
            Panels.toggle(app.panelKey)
            return
        }
        // Strip Desktop Entry field-code placeholders (%u %f %F %U %d
        // %D %n %i %c %k %v) from the Exec command — some desktop entries
        // return the raw `Exec=foo %u` string, and execDetached gets
        // argv literally, so the token would end up as a broken arg.
        var cmd = app.command || []
        if (cmd.length > 0) {
            cmd = cmd.map(arg => arg.replace(/%[u fodDknickv]/g, "").trim())
            cmd = cmd.filter(arg => arg !== "")
        }
        Quickshell.execDetached({
            command: cmd,
            workingDirectory: app.workingDirectory,
            environment: ({ "XDG_CURRENT_DESKTOP": "Hyprland" })
        })
        root.visible = false
    }

    rowDelegate: SearchRow {
        id: appRow
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            // Panel entries get the Quickshell logo (copied into assets/
            // from the package's org.quickshell.svg — not resolvable via
            // iconPath, it isn't installed into the system icon theme).
            source: appRow.modelData?.panelKey
                ? "file://" + Quickshell.shellDir + "/assets/quickshell-logo.svg"
                : appRow.modelData?.icon ? Quickshell.iconPath(appRow.modelData.icon, false) : ""
            width: Theme.iconSize
            height: Theme.iconSize
            visible: source.toString() !== ""
        }
        ThemeText {
            anchors.verticalCenter: parent.verticalCenter
            text: appRow.modelData?.name ?? ""
        }
    }
}