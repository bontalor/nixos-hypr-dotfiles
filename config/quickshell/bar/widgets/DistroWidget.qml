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
    property string logoPath: "/run/current-system/sw/share/icons/hicolor/scalable/apps/nix-snowflake.svg"

    function setLogo(content) {
        if (!content) { logoPath = "/run/current-system/sw/share/icons/hicolor/scalable/apps/nix-snowflake.svg"; return }
        for (var line of content.split("\n")) {
            if (line.startsWith("ID=")) {
                var id = line.substring(3).replace(/"/g, "").trim()
                var paths = {
                    "arch": assetsDir + "/archlinux-logo.svg",
                    "nixos": "/run/current-system/sw/share/icons/hicolor/scalable/apps/nix-snowflake.svg",
                }
                logoPath = paths[id] || ""
                return
            }
        }
    }

    Process {
        id: distroProbe
        command: ["cat", "/etc/os-release"]
        running: true
        onStdoutChanged: root.setLogo(stdout)
    }

    Component.onCompleted: {
        if (distroProbe.stdout) root.setLogo(distroProbe.stdout)
    }

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? Qt.alpha(Colors.base08, 0.75) : "transparent"
        radius: 0
    }

    Image {
        id: logoImage
        anchors.centerIn: parent
        width: 22
        height: 22
        source: "file:///" + root.logoPath
        fillMode: Image.PreserveAspectFit
        sourceSize.width: 22
        sourceSize.height: 22
        visible: status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        text: "\uf303"
        font.pixelSize: 22
        font.family: "JetBrainsMono Nerd Font"
        color: Colors.foreground
        visible: logoImage.status !== Image.Ready
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: launcherToggle.running = true
    }

    Process {
        id: launcherToggle
        command: ["qs", "ipc", "call", "overlay", "toggle", "launcher"]
        running: false
    }
}
