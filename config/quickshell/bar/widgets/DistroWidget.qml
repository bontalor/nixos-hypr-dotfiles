import "../../theme"
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    width: 30
    height: 30
    clip: true

    readonly property string assetsDir: Quickshell.shellDir + "/assets"

    property string distroContent: ""

    FileView {
        path: "/etc/os-release"
        watchChanges: false
        onLoaded: root.distroContent = text()
    }

    property string logoPath: computeLogoPath(distroContent)

    function computeLogoPath(content) {
        if (!content) return "/run/current-system/sw/share/icons/hicolor/scalable/apps/nix-snowflake.svg"
        var lines = content.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].startsWith("ID=")) {
                var id = lines[i].substring(3).replace(/"/g, "").trim()
                var paths = {
                    "arch": assetsDir + "/archlinux-logo.svg",
                    "nixos": "/run/current-system/sw/share/icons/hicolor/scalable/apps/nix-snowflake.svg",
                }
                return paths[id] || ""
            }
        }
        return ""
    }

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? Qt.alpha(Colors.foreground, 0.25) : "transparent"
        radius: 0
    }

    Image {
        id: logoImage
        anchors.centerIn: parent
        width: Theme.iconSize
        height: Theme.iconSize
        source: root.logoPath ? "file://" + root.logoPath : ""
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Theme.iconSize
        sourceSize.height: Theme.iconSize
        visible: status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        text: Icon.distroFallback
        font.pixelSize: Theme.fontPixelSizeLarge
        font.family: Theme.fontFamily
        color: Colors.foreground
        visible: logoImage.status !== Image.Ready
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("launcher")
    }
}