import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: root
    title: "Wallpaper Picker"
    color: "transparent"

    implicitWidth: 850
    implicitHeight: 450

    visible: false

    onClosed: visible = false

    property ListModel wallpapers: ListModel {}
    property int selected: 0
    property int columns: 4

    signal toggle()

    function scan() {
        scanner.command = ["bash", "-c", "ls -1 " + Quickshell.env("HOME") + "/walls/*.{jpg,jpeg,png,gif,webp,bmp} 2>/dev/null"]
        scanner.running = true
    }

    Component.onCompleted: scan()

    onVisibleChanged: {
        if (visible) scan()
    }

    Process {
        id: scanner
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.wallpapers.clear()
                var files = text.trim().split('\n')
                for (var i = 0; i < files.length; i++) {
                    var f = files[i].trim()
                    if (f.length > 0) {
                        root.wallpapers.append({ path: f })
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        focus: root.visible

        Keys.onPressed: event => {
            switch (event.key) {
                case Qt.Key_H:
                root.selected = Math.max(0, root.selected - 1)
                break
                case Qt.Key_J:
                root.selected = Math.min(root.wallpapers.count - 1, root.selected + root.columns)
                break
                case Qt.Key_K:
                root.selected = Math.max(0, root.selected - root.columns)
                break
                case Qt.Key_L:
                root.selected = Math.min(root.wallpapers.count - 1, root.selected + 1)
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
            if (root.wallpapers.count === 0) return
            var path = root.wallpapers.get(root.selected).path
            setter.command = ["bash", "-c", "~/.local/bin/setwall '" + path + "'"]
            setter.running = true
            root.visible = false
        }

        
        GridView {
            id: grid
            anchors { left: parent.left; leftMargin: 10; right: parent.right; top: parent.top; topMargin: 10; bottom: parent.bottom; bottomMargin: 10 }
            model: root.wallpapers
            cellWidth: 210
            cellHeight: 146.5
            interactive: false
            highlightRangeMode: GridView.StrictlyEnforceRange
            snapMode: GridView.SnapToRow

            delegate: Item {
                width: grid.cellWidth - 10
                height: grid.cellHeight - 10

                Image {
                    anchors.fill: parent
                    source: model.path
                    sourceSize.width: 200
                    sourceSize.height: 140
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: "transparent"
                    border.width: index === root.selected ? 5 : 0
                    border.color: Colors.base05
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
