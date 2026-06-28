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

    // --- Panel geometry ---
    property int panelWidth: 850
    property int panelHeight: 450
    property int margin: 10
    property int colSpacing: 10

    // Two-pane scaffold (see theme/Panel.qml)
    property int rowHeight: 45
    property int headerHeight: 30

    // Search-list scaffold (Launcher/EmojiPicker/PowerMenu)
    property int searchRowHeight: 30
    property int searchRowStride: 40        // rowHeight + spacing used by scrollToSelected
    property int iconSize: 22

    // --- Alphas ---
    property real alphaBackground: 0.75     // Qt.alpha(Colors.base00, 0.75)
    property real alphaSelected: 0.75       // Qt.alpha(Colors.base01, 0.75)
    property real alphaSectionHeader: 0.75  // Qt.alpha(Colors.base0d, 0.75)
    property real alphaHover: 0.5

    // --- Battery thresholds ---
    property int batteryCritical: 15
    property int batteryWarning: 25

    // --- Audio visualizer ---
    property int peakFps: 20
    property int peakBands: 8
}