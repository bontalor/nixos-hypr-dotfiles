import "../theme"
import "."
import QtQuick
import Quickshell
import Quickshell.Widgets

FloatingWindow {
    id: root
    title: "App Launcher"
    color: "transparent"
    implicitWidth: 850
    implicitHeight: 450
    visible: false

    onClosed: visible = false

    property var allApps: []

    Component.onCompleted: rebuildApps()
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { rebuildApps() }
    }

    function rebuildApps() {
        allApps = [...DesktopEntries.applications.values]
            .filter(a => a.name)
            .sort((a, b) => a.name.localeCompare(b.name))
    }

    property var filteredApps: {
        var q = searchText.text.trim().toLowerCase()
        if (q === "") return allApps
        var matches = allApps.filter(a =>
            a.name.toLowerCase().includes(q) ||
            (a.genericName || "").toLowerCase().includes(q) ||
            (a.comment || "").toLowerCase().includes(q)
        )
        return fuzzySort(q, matches)
    }

    function fuzzySort(query, items) {
        var q = query.toLowerCase()
        return items.sort(function(a, b) {
            var aName = a.name.toLowerCase()
            var bName = b.name.toLowerCase()
            var aIdx = aName.indexOf(q)
            var bIdx = bName.indexOf(q)
            if (aIdx === 0 && bIdx !== 0) return -1
            if (bIdx === 0 && aIdx !== 0) return 1
            if (aName.length !== bName.length) return aName.length - bName.length
            if (aIdx !== bIdx) return aIdx - bIdx
            if (aName < bName) return -1
            if (aName > bName) return 1
            return 0
        })
    }

    property int selectedIndex: 0

    function launchSelected() {
        var app = filteredApps[selectedIndex]
        if (app) {
            Quickshell.execDetached({
                command: app.command,
                workingDirectory: app.workingDirectory,
                environment: ({ "XDG_CURRENT_DESKTOP": "Hyprland" })
            })
            root.visible = false
        }
    }

    onVisibleChanged: {
        if (visible) {
            searchText.text = ""
            selectedIndex = 0
            searchText.forceActiveFocus()
        }
    }

    onSelectedIndexChanged: {
        if (resultFlick) resultFlick.scrollToSelected()
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                width: parent.width
                height: 30
                color: Qt.alpha(Colors.base00, 0.75)
                clip: true

                TextInput {
                    id: searchText
                    anchors {
                        left: parent.left; leftMargin: 10
                        right: parent.right; rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    color: Colors.foreground
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    onTextChanged: selectedIndex = 0

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Down:
                            selectedIndex = Math.min(selectedIndex + 1, filteredApps.length - 1)
                            event.accepted = true; break
                        case Qt.Key_Up:
                            selectedIndex = Math.max(selectedIndex - 1, 0)
                            event.accepted = true; break
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            launchSelected()
                            event.accepted = true; break
                        case Qt.Key_Escape:
                            root.visible = false
                            event.accepted = true; break
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: parent.height - 40
                color: Qt.alpha(Colors.base00, 0.75)

                Flickable {
                    id: resultFlick
                    anchors.fill: parent
                    anchors.margins: 10
                    contentHeight: resultCol.height
                    clip: true

                    function scrollToSelected() {
                        var y = selectedIndex * 40
                        var h = 30
                        var viewH = resultFlick.height
                        var maxY = Math.max(0, resultCol.height - viewH)
                        if (y < resultFlick.contentY) {
                            resultFlick.contentY = Math.max(0, y - 10)
                        } else if (y + h > resultFlick.contentY + viewH) {
                            resultFlick.contentY = Math.min(maxY, y + h - viewH + 10)
                        }
                    }

                    Column {
                        id: resultCol
                        width: parent.width
                        spacing: 10

                        Repeater {
                            model: filteredApps

                            delegate: Rectangle {
                                width: parent.width
                                height: 30
                                color: index === selectedIndex ? Qt.alpha(Colors.base01, 0.75) : "transparent"

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left; anchors.leftMargin: 10
                                    spacing: 10

                                    IconImage {
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: modelData?.icon ? Quickshell.iconPath(modelData.icon, false) : ""
                                        width: 22; height: 22
                                        visible: source.toString() !== ""
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData?.name ?? ""
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { selectedIndex = index; launchSelected() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
