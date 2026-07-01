import "../theme"
import "../util"
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: root
    title: "Wallpaper Picker"
    color: "transparent"

    implicitWidth: Theme.panelWidth
    implicitHeight: Theme.panelHeight

    visible: false

    onClosed: visible = false

    property int selected: 0

    // Columns actually laid out by the GridView (as many cells as fit
    // its width), so J/K row jumps stay correct when the window is
    // resized. Previously a hardcoded 4.
    readonly property int columns: Math.max(1, Math.floor(grid.width / grid.cellWidth))

    // The last-applied wallpaper path, persisted across sessions via
    // PrefStore; used to set `selected` to the matching index when the
    // picker opens.
    property string lastWallpaper: PrefStore.wallpaper

    // Cache the wallpaper list once per scan instead of rescanning the
    // directory every time the picker is opened. FolderListModel watches
    // the folder natively and re-fires `status` whenever something
    // changes — no shell-out / `ls`.
    property var wallpaperList: []
    function syncFromModel() {
        var list = []
        // Note: Qt 6.11 FolderListModel only exposes `filePath` (local
        // path string), not `fileURL` — using the wrong role silently
        // returns undefined.
        for (var i = 0; i < wallpaperModel.count; i++) {
            var p = wallpaperModel.get(i, "filePath")
            if (!p) continue
            list.push({ path: p })
        }
        root.wallpaperList = list
        // If we have a persisted wallpaper, jump to its index.
        if (root.lastWallpaper) root.restoreSelection()
    }

    function restoreSelection() {
        for (var i = 0; i < root.wallpaperList.length; i++) {
            if (root.wallpaperList[i].path === root.lastWallpaper) {
                root.selected = i
                return
            }
        }
    }

    FolderListModel {
        id: wallpaperModel
        folder: "file://" + Paths.wallpaperDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp", "*.bmp"]
        sortField: FolderListModel.Name
        showDirs: false
        showOnlyReadable: true
        onStatusChanged: if (status === FolderListModel.Ready) root.syncFromModel()
        onCountChanged: if (status === FolderListModel.Ready) root.syncFromModel()
    }

    onVisibleChanged: if (visible) root.restoreSelection()

    function applyWallpaper() {
        if (wallpaperList.length === 0) return
        var path = wallpaperList[root.selected].path
        setter.command = [Paths.setwallBin, path]
        setter.running = true
        // Persist the selected path so the picker reopens at the
        // last-applied wallpaper (lastWallpaper follows via binding).
        PrefStore.wallpaper = path
        root.visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        focus: root.visible

        Keys.onPressed: event => {
            switch (event.key) {
                case Qt.Key_H:
                root.selected = Scroll.clamp(root.selected - 1, 0, wallpaperList.length - 1)
                break
                case Qt.Key_J:
                root.selected = Scroll.clamp(root.selected + root.columns, 0, wallpaperList.length - 1)
                break
                case Qt.Key_K:
                root.selected = Scroll.clamp(root.selected - root.columns, 0, wallpaperList.length - 1)
                break
                case Qt.Key_L:
                root.selected = Scroll.clamp(root.selected + 1, 0, wallpaperList.length - 1)
                break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                root.applyWallpaper()
                break
                case Qt.Key_Escape:
                root.visible = false
                break
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.margin
            color: Qt.alpha(Colors.base00, Theme.alphaBackground)

            GridView {
                id: grid
                anchors.fill: parent
                // Right/bottom anchor margins stay 0 — each cell already
                // carries Theme.margin of padding on those sides (the
                // delegate is cellWidth/Height - 10), so adding anchor
                // margins would double them at the edges.
                anchors { leftMargin: Theme.margin; rightMargin: 0; topMargin: Theme.margin; bottomMargin: 0 }
                model: root.wallpaperList
                cellWidth: 205
                cellHeight: 140
                clip: true
                // Interactive so the mouse wheel / touchpad scrolls the
                // grid; keyboard selection still repositions the view
                // via Scroll.scrollIntoView below. StopAtBounds matches
                // the no-overshoot scrolling of every other panel's
                // Flickable.
                interactive: true
                boundsBehavior: Flickable.StopAtBounds

                // Off-screen thumbnails are dropped from Qt's image cache to
                // avoid retaining hundreds of decoded bitmaps when the
                // user has a large walls directory.
                delegate: Item {
                    width: grid.cellWidth - 10
                    height: grid.cellHeight - 10

                    Image {
                        anchors.fill: parent
                        source: modelData.path
                        sourceSize.width: 195
                        sourceSize.height: 130
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true
                    }

                    // Same border for keyboard selection and mouse hover,
                    // matching the selected-or-hovered highlight used by
                    // rows elsewhere in the shell.
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: index === root.selected || cellMouse.containsMouse ? 5 : 0
                        border.color: Colors.base05
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selected = index
                            root.applyWallpaper()
                        }
                    }
                }
            }
        }
    }

    Process {
        id: setter
        running: false
    }

    // Keep the keyboard selection visible via the shared Scroll helper
    // (same as SearchPanel/Panel). Passing the full cellHeight — which
    // includes the cell's built-in Theme.margin of bottom padding — means
    // downward scrolls rest with a 10px gap under the thumbnail, matching
    // the launcher's feel. GridView.Contain left the thumbnail flush
    // with the viewport edge instead.
    onSelectedChanged: {
        var row = Math.floor(root.selected / root.columns)
        Scroll.scrollIntoView(grid, row * grid.cellHeight, grid.cellHeight)
    }
}
