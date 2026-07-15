// Subprocess dependencies: ~/.local/bin/setwall (applies wallpaper
// image — user-provided script, expected on $PATH).

import "../theme"
import "../components"
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

    // Panels registry key — same self-registration as components/Panel.qml.
    property string panelKey: ""
    Component.onCompleted: if (panelKey !== "") Panels.register(panelKey, this)

    property int selected: 0

    // Columns actually laid out by the GridView (as many cells as fit
    // its width), so J/K row jumps stay correct when the window is
    // resized. Previously a hardcoded 4.
    readonly property int columns: Math.max(1, Math.floor(grid.width / grid.cellWidth))

    // Currently-applied wallpaper path, as the OS sees it. The picker
    // previously keyed its initial selection off `PrefStore.wallpaper`
    // — the last file picked *through this UI*. If `setwall` (or any
    // other pywal front-end) was run outside the picker, that pref would
    // be out of sync, so the picker opened on a stale selection. pywal
    // records the truly-current wallpaper in `~/.cache/wal/wal` as a
    // one-line file; we read that and fall back to the pref if the file
    // is missing or its entry isn't in the directory.
    property string currentWalPath: ""
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
        root.restoreSelection()
    }

    function restoreSelection() {
        // Prefer `~/.cache/wal/wal` (the OS-applied wallpaper) over the
        // picker pref; fall back to the pref if the pywal record is empty
        // or names a file not in this directory.
        var target = root.currentWalPath !== "" ? root.currentWalPath : root.lastWallpaper
        if (target !== "") {
            for (var i = 0; i < root.wallpaperList.length; i++) {
                if (root.wallpaperList[i].path === target) {
                    root.selected = i
                    return
                }
            }
        }
        // No match — clamp to 0 so an unrelated persisted path doesn't
        // land selection on a silently-deleted index.
        root.selected = 0
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

    // Read `~/.cache/wal/wal` (pywal's record of the currently-applied
    // wallpaper — a one-line absolute path). Refreshed each time the picker
    // opens so out-of-band wallpaper changes are reflected. The cat is
    // cheap; just one-line stdout, captured synchronously via waitForEnd.
    Process {
        id: walReader
        running: false
        command: ["cat", Paths.walWallpaper]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.currentWalPath = text.trim()
                root.restoreSelection()
            }
        }
    }

    onVisibleChanged: if (visible) {
        // Have the list re-read selection using the fresh wal value when
        // it arrives; if the list is already populated, restoreSelection
        // runs from onStreamFinished above.
        root.restoreSelection()
        walReader.running = true
    }

    function applyWallpaper() {
        if (wallpaperList.length === 0) return
        // `selected` can point past the end if files were deleted since
        // the selection was made (the model resync doesn't re-clamp it).
        var path = wallpaperList[Scroll.clamp(root.selected, 0, wallpaperList.length - 1)].path
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
            color: Qt.alpha(Colors.surface, Theme.alphaBackground)

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
                        border.color: Colors.border
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

    CheckedProcess {
        id: setter
        label: "setwall"
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
