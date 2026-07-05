import "../../theme"
import "../../components"
import "../../util"
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

    // A custom icon set in Settings wins; "" falls back to detection.
    property string logoPath: PrefStore.distroIcon
        ? Paths.expandHome(PrefStore.distroIcon)
        : computeLogoPath(distroContent)

    function computeLogoPath(content) {
        if (!content) return root.nixosLogo
        var lines = content.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].startsWith("ID=")) {
                var id = lines[i].substring(3).replace(/"/g, "").trim()
                // Add per-distro entries here alongside their assets/
                // files; unmatched distros fall back to the
                // Icon.distroFallback glyph below.
                var paths = {
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

    ThemeText {
        anchors.centerIn: parent
        text: Icon.distroFallback
        size: "large"
        visible: logoImage.status !== Image.Ready
    }
}
