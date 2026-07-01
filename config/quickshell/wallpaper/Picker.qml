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
    property int columns: 4

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
                applyWallpaper()
                break
                case Qt.Key_Escape:
                root.visible = false
                break
            }
        }

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
            anchors.margins: Theme.margin
            color: Qt.alpha(Colors.base00, Theme.alphaBackground)

            GridView {
                id: grid
                anchors.fill: parent
                anchors { leftMargin: Theme.margin; rightMargin: 0; topMargin: Theme.margin; bottomMargin: Theme.margin }
                model: root.wallpaperList
                cellWidth: 205
                cellHeight: 140
                clip: true
                interactive: false
                highlightRangeMode: GridView.StrictlyEnforceRange
                snapMode: GridView.SnapToRow

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

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: index === root.selected ? 5 : 0
                        border.color: Colors.base05
                    }
                }
            }
        }
    }

    Process {
        id: setter
        running: false
    }

    onSelectedChanged: {
        grid.positionViewAtIndex(root.selected, GridView.Contain)
    }
}
