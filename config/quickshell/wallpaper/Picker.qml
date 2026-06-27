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

    property string rawScanText: ""
    property var wallpaperList: parseWallpapers(rawScanText)
    property int selected: 0
    property int columns: 4

    signal toggle()

    function parseWallpapers(text) {
        var model = []
        var files = text.trim().split('\n')
        for (var i = 0; i < files.length; i++) {
            var f = files[i].trim()
            if (f.length > 0) model.push({ path: f })
        }
        return model
    }

    function scan() {
        scanner.command = ["bash", "-c", "ls -1 \"$1\"/walls/*.{jpg,jpeg,png,gif,webp,bmp} 2>/dev/null", "sh", Quickshell.env("HOME")]
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
            onStreamFinished: rawScanText = text
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
                root.selected = Math.min(wallpaperList.length - 1, root.selected + root.columns)
                break
                case Qt.Key_K:
                root.selected = Math.max(0, root.selected - root.columns)
                break
                case Qt.Key_L:
                root.selected = Math.min(wallpaperList.length - 1, root.selected + 1)
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
            setter.command = [Quickshell.env("HOME") + "/.local/bin/setwall", path]
            setter.running = true
            root.visible = false
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: Qt.alpha(Colors.base00, 0.75)

            GridView {
                id: grid
                anchors.fill: parent
                anchors { leftMargin: 10; rightMargin: 0; topMargin: 10; bottomMargin: 10 }
                model: wallpaperList
                cellWidth: 205
                cellHeight: 140
                clip: true
                interactive: false
                highlightRangeMode: GridView.StrictlyEnforceRange
                snapMode: GridView.SnapToRow

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
                        cache: true
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
