import "../../theme"
import QtQuick
import Quickshell
import Quickshell.Io

WidgetButton {
    id: root

    readonly property string assetsDir: Quickshell.shellDir + "/assets"

    // Single source of truth for the NixOS logo path (previously
    // duplicated as both the fallback default and the table entry).
    readonly property string nixosLogo: "/run/current-system/sw/share/icons/hicolor/scalable/apps/nix-snowflake.svg"

    property string distroContent: ""

    FileView {
        path: "/etc/os-release"
        watchChanges: false
        onLoaded: root.distroContent = text()
    }

    property string logoPath: computeLogoPath(distroContent)

    function computeLogoPath(content) {
        if (!content) return root.nixosLogo
        var lines = content.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].startsWith("ID=")) {
                var id = lines[i].substring(3).replace(/"/g, "").trim()
                var paths = {
                    "arch": assetsDir + "/archlinux-logo.svg",
                    "nixos": root.nixosLogo,
                }
                return paths[id] || ""
            }
        }
        return ""
    }

    panel: Panels.launcher

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
}
