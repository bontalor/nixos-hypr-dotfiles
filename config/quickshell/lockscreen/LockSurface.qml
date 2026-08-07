// Subprocess dependencies: systemctl (suspend/reboot/poweroff),
// loginctl (terminate-user logout) — same power actions as PowerMenu.

pragma ComponentBehavior: Bound

import "./theme"
import "./components"
import "./util"
import "./models"
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Rectangle {
    id: root
    required property LockContext context
    color: Colors.background

    property string wallpaperPath: ""

    // blockLoading: true makes the initial text() call synchronous — the
    // onLoaded signal fires before the first frame is rendered, so
    // wallpaperPath is set (and Image starts decoding) before any paint.
    FileView {
        path: Paths.walWallpaper
        blockLoading: true
        watchChanges: true
        onLoaded: root.wallpaperPath = text().trim()
        onFileChanged: root.wallpaperPath = text().trim()
    }

    // Sharp wallpaper — fills the screen unmodified (the user wants
    // the wall visible behind the lock panel, not blurred everywhere).
    Image {
        id: wallImage
        anchors.fill: parent
        source: wallpaperPath ? "file://" + wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
    }

    property string formattedDate: FormatUtil.formattedDate(clock.date)

    property var lockActions: PowerActions.actions.filter(function(a) {
        return !a._lockOnly
    })

    Rectangle {
        id: panel
        x: (parent.width - Theme.panelWidth) / 2
        y: (parent.height - Theme.panelHeight) / 2
        width: Theme.panelWidth - Theme.margin
        height: Theme.panelHeight - Theme.margin
        color: "transparent"   // backdrop handles the tint — see below
        z: 1   // sit above the DropShadow sibling (z: 0) declared after
        // Hard clip: MultiEffect's blur kernel (and autoPaddingEnabled,
        // which lets the blurred FBO extend past the source bounds) would
        // otherwise bleed outside the panel. Clipping the panel Rectangle
        // contains every child (the backdrop Item, the tint, the Column)
        // to exactly the panel rect, so the frosted glass stays framed.
        clip: true

        // Frosted-glass backdrop scoped to exactly this panel rect.
        // ext-session-lock-v1 surfaces are NOT wlr-layer-shell
        // windows, so Hyprland's `layerrule = blur` can't reach the
        // lockscreen — the blur lives in the QtQuick scene. The Item
        // is anchored.fill to the panel and rendered to an offscreen
        // FBO via `layer.enabled`; MultiEffect (as `layer.effect`)
        // runs a Gaussian over that FBO. The Image inside is the
        // sharp wall placed at -panel.x/-panel.y so each pixel lands
        // at the same on-screen coordinate as the wall behind the
        // panel — the FBO captures exactly the wall patch that would
        // have shown at the panel's location, and only that rect is
        // blurred. `transparentBorder: true` lets the blur fall off
        // past the panel edge instead of clamping to FBO border
        // pixels (no seam), and the tint Rectangle below covs the
        // slightly transparent rim. Params mirror the user's Hyprland
        // blur (size=8, passes=3, noise=0, contrast=1, brightness=1,
        // vibrancy=1 — i.e. unity everywhere except the blur radius).
        Item {
            id: panelBackdrop
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: Theme.lockWallpaperBlur
                blurMax: Theme.lockWallpaperBlurMax
                blurMultiplier: 1.0
                // autoPaddingEnabled defaults to true — that resizes
                // MultiEffect's drawn output to `source + blurMax × 2`
                // so the kernel has padding to sample past the FBO
                // edge. We disable it: the parent panel Rectangle's
                // `clip: true` is what contains any bleed, and turning
                // auto-padding off stops MultiEffect from drawing
                // outside the Item at all (the blurred result stays
                // within the source rect, bluffing a slightly darker
                // rim at the very edge — fine, hidden by the tint
                // Rectangle stacked on top).
                autoPaddingEnabled: false
                brightness: Theme.lockWallpaperBrightness
                contrast: Theme.lockWallpaperContrast
                saturation: Theme.lockWallpaperSaturation
                // `noise` and `transparentBorder` aren't exposed by
                // QtQuick.Effects/MultiEffect on this Qt — Hyprland's
                // `noise = 0` is unity anyway.
            }

            Image {
                // The wall Image is anchored to root (0,0); inside
                // this panel-local Item, place it at -panel.x/-panel.y
                // so its pixels line up with the sharp wall on screen.
                x: -panel.x
                y: -panel.y
                width: root.width
                height: root.height
                source: wallImage.source
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
            }
        }

        // Translucent tint at Theme.alphaWindow — gives the frosted
        // backdrop the panel's characteristic solid feel (the previous
        // flat Qt.alpha(Colors.background, alphaWindow) panel color).
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colors.background, Theme.alphaWindow)
        }

        Column {
            anchors.centerIn: parent
            width: Theme.lockContentWidth
            spacing: Theme.margin
            Item {
                width: parent.width
                height: Theme.lockClockHeight
                SystemClock {
                    id: clock
                    precision: SystemClock.Seconds
                }
                Text {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSizeDisplay
                    font.family: Theme.fontFamily
                    font.bold: true
                    text: Qt.formatDateTime(clock.date, PrefStore.timeFormat === "24h" ? "HH:mm:ss" : "h:mm:ss AP")
                }
            }
            Item {
                width: parent.width
                height: Theme.lockStatusHeight
                ThemeText {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.formattedDate
                }
            }
            Row {
                width: parent.width
                height: Theme.headerHeight
                spacing: context.fingerprintEnabled ? Theme.margin : 0
                Rectangle {
                    width: parent.width - (context.fingerprintEnabled ? Theme.lockFpReserve : 0)
                    height: Theme.headerHeight
                    color: Qt.alpha(Colors.background, Theme.alphaBackground)
                    clip: true
                    TextInput {
                        id: passwordBox
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: Theme.margin
                            rightMargin: Theme.margin
                        }
                        color: Colors.foreground
                        font.pixelSize: Theme.fontPixelSize
                        font.letterSpacing: Theme.lockInputLetterSpacing
                         font.family: Theme.fontFamily
                         focus: true
                         echoMode: TextInput.Password
                         passwordCharacter: "■"
                         inputMethodHints: Qt.ImhSensitiveData
                         Component.onCompleted: forceActiveFocus()
                         onActiveFocusChanged: {
                             if (!activeFocus) forceActiveFocus()
                         }
                         onTextChanged: root.context.currentText = this.text
                         onAccepted: root.context.tryUnlock()
                        Text {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                                leftMargin: Theme.margin
                            }
                            color: Colors.foreground
                            font.pixelSize: Theme.fontPixelSize
                            font.family: Theme.fontFamily
                            text: "Enter password..."
                            visible: parent.text.length === 0
                        }
                        Connections {
                            target: root.context
                            function onCurrentTextChanged() {
                                if (passwordBox.text !== root.context.currentText) {
                                    passwordBox.text = root.context.currentText
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    width: context.fingerprintEnabled ? Theme.lockFpButtonWidth : 0
                    height: Theme.headerHeight
                    visible: context.fingerprintEnabled
                    color: context.fingerprintFailed
                        ? Qt.alpha(Colors.critical, Theme.alphaBackground)
                        : Qt.alpha(Colors.background, Theme.alphaBackground)
                    ThemeText {
                        anchors.centerIn: parent
                        text: Icon.fingerprint
                        size: "large"
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.lockActionSpacing
                Repeater {
                    model: root.lockActions
                    delegate: Column {
                        required property var modelData
                        spacing: Theme.margin
                        width: Theme.lockActionColumnWidth
                        Rectangle {
                            width: Theme.actionButtonSize
                            height: Theme.actionButtonSize
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: btnMouse.containsMouse ? Qt.alpha(Colors.accent, Theme.alphaSectionHeader + Theme.alphaHover) : Qt.alpha(Colors.accent, Theme.alphaSectionHeader)
                            ThemeText {
                                anchors.centerIn: parent
                                text: modelData?.glyph ?? ""
                                size: "large"
                            }
                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached({ command: modelData.command })
                                }
                            }
                        }
                        ThemeText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData?.name ?? ""
                        }
                    }
                }
            }
            Item {
                width: parent.width
                height: Theme.lockStatusHeight
                ThemeText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: context.fingerprintScanning
                    text: "waiting for scan..."
                }
            }
        }
        ThemeText {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.margin
            anchors.horizontalCenter: parent.horizontalCenter
            visible: context.showFailure
            text: "Incorrect password"
        }
    }

    // Drop shadow for the frosted panel — uses the shared
    // components/DropShadow.qml L-shaped strip (the same one Bar.qml and
    // the popups use), sized to `panel rect + Theme.margin` so the right
    // and bottom strips align with the panel's edges. The previous
    // `DropShadow { ... }` here was using the Qt5Compat GraphicalEffects
    // type (not imported) with no `source` and silently rendered nothing;
    // this version uses the in-shell strip pair and actually draws.
    // `z: 0` puts it behind the panel sibling (`z: 1`).
    DropShadow {
        x: panel.x
        y: panel.y
        width: panel.width + Theme.margin
        height: panel.height + Theme.margin
        extent: Theme.margin
        z: 0
    }
}
