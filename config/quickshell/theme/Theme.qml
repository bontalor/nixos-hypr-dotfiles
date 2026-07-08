pragma Singleton

import QtQuick
import Quickshell

// Centralized visual theme. Single source of truth for fonts, sizes, alphas,
// and panel geometry. Add shared visual constants here; domain tunables
// (refresh intervals, history caps, thresholds) live on their domain
// singleton (NotifDaemon, ClipboardModel, BatteryModel, OsdModel, …) —
// only constants used across domains stay here.

Singleton {
    // --- Fonts ---
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontPixelSize: 16
    property int fontPixelSizeLarge: 22
    property int fontPixelSizeXLarge: 30
    property int fontPixelSizeSmall: 12

    // --- Bar geometry ---
    property int barHeight: 30
    property int barMargin: 10
    // Tray icons shown inline before overflowing into the dropdown.
    property int trayMaxVisible: 3

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

    // Two-pane scaffold (see components/Panel.qml)
    property int rowHeight: 45
    property int headerHeight: 30
    property int subHeaderHeight: 20   // SectionSubHeader rows ("My devices", …)

    // Search-list scaffold (Launcher/EmojiPicker/PowerMenu)
    property int searchRowHeight: 30
    property int searchRowStride: searchRowHeight + margin
    property int iconSize: 22

    // --- Alphas ---
    property real alphaBackground: 0.75     // Qt.alpha(Colors.surface, 0.75)
    property real alphaSelected: 0.75       // Qt.alpha(Colors.selected, 0.75)
    property real alphaSectionHeader: 0.75  // Qt.alpha(Colors.accent, 0.75)
    property real alphaHover: 0.25          // Qt.alpha(Colors.foreground, alphaHover) — bar widget hover
    property real alphaWindow: 0.76         // Qt.alpha(Colors.background, alphaWindow) — bar/popup solid bg
    property real alphaInactive: 0.25       // Qt.alpha(Colors.foreground, alphaInactive) — unlit meter dots / empty bar track
    property real alphaDim: 0.5             // Qt.alpha(Colors.foreground, alphaDim) — dimmed metadata text

    // --- Audio visualizer (shared by media/SpectrumModel, VolumePanel,
    // and the bar's MediaWidget) ---
    // peakFps drives both the spectrum helper's frame rate (spectrum.py
    // restarts with the new value on reload) and VolumePanel's meters.
    property int peakFps: 16
    property int peakBands: 15
    property real peakDecay: 0.05

    // Volume step per key/scroll tick (bar widget, VolumePanel, OSD).
    property real volumeStep: 0.05

    property int osdBarHeight: 10       // value bar thickness in OsdPopup
    property int marqueeSpeed: 25       // ms per pixel — lower is faster
}
