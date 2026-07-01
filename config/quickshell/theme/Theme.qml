pragma Singleton

import QtQuick
import Quickshell

// Centralized visual theme. Single source of truth for fonts, sizes, alphas,
// and panel geometry. Add new shared constants here rather than hardcoding
// them in panels.

Singleton {
    // --- Fonts ---
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontPixelSize: 16
    property int fontPixelSizeLarge: 22
    property int fontPixelSizeSmall: 12

    // --- Bar geometry ---
    property int barHeight: 30
    property int barMargin: 10

    // --- Panel geometry ---
    property int panelWidth: 850
    property int panelHeight: 450
    property int margin: 10
    property int colSpacing: 10

    // Popups (notifications, OSD). Smaller than panels. The `+ margin`
    // popup*WithShadow values account for the DropShadow pair extending
    // right/below — consumers size the PanelWindow to the WithShadow
    // value and the inner content to the plain value.
    property int popupWidth: 270
    property int popupHeight: 90
    property int popupWidthWithShadow: popupWidth + margin
    property int popupHeightWithShadow: popupHeight + margin

    // Two-pane scaffold (see theme/Panel.qml)
    property int rowHeight: 45
    property int headerHeight: 30

    // Search-list scaffold (Launcher/EmojiPicker/PowerMenu)
    property int searchRowHeight: 30
    property int searchRowStride: searchRowHeight + margin
    property int iconSize: 22

    // --- Alphas ---
    property real alphaBackground: 0.75     // Qt.alpha(Colors.base00, 0.75)
    property real alphaSelected: 0.75       // Qt.alpha(Colors.base01, 0.75)
    property real alphaSectionHeader: 0.75  // Qt.alpha(Colors.base0d, 0.75)
    property real alphaHover: 0.25          // Qt.alpha(Colors.foreground, alphaHover) — bar widget hover
    property real alphaWindow: 0.76         // Qt.alpha(Colors.background, alphaWindow) — bar/popup solid bg

    // --- Battery thresholds ---
    property int batteryCritical: 15
    property int batteryWarning: 25

    // --- Audio visualizer ---
    property int peakFps: 20
    property int peakBands: 8

    // --- OSD ---
    property int osdHideInterval: 3000
    property int osdBarHeight: 8           // value bar thickness in OsdPopup
    property real volumeStep: 0.05
    property int brightnessStep: 5
    property real volumeGlyphThreshold: 0.5

    // --- Notifications ---
    property int notifExpireMillis: 5000
    property int maxPopups: 3

    // --- Weather refresh ---
    property int weatherRefreshMillis: 600000
}
