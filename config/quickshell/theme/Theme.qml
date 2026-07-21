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
    property int fontPixelSizeHeader: 24       // mid-emphasis (date line in DateTimePanel)
    property int fontPixelSizeDisplay: 32      // large display (lockscreen clock, weather temps)
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

    // Small meter thickness / segmented-dot size. Used by:
    //   - OSD popup value bar (osd/OsdPopup.qml)
    //   - FFmpeg progress bar (ffmpeg/FfmpegPanel.qml)
    //   - Volume bars + peak dots (volume/AudioDeviceRow.qml)
    //   - Wi-Fi signal dots (network/NetworkPanel.qml)
    //   - Media seek bar (media/MediaPanel.qml)
    // Keeps the segmented-meter look uniform across the shell.
    property int meterHeight: 10
    property int marqueeSpeed: 25       // ms per pixel — lower is faster

    // --- Per-domain display sizes (hoisted for centralized tuning) ---
    //
    // These belong to one domain each (not "shared across domains"),
    // but live here so the visual rhythm of the shell stays tunable
    // from a single file rather than scattered as magic numbers.
    //
    // Media now-playing UI.
    property int albumArtSize: 220          // square album art in MediaPanel
    // Square icon-button size. Used across domains: media transport
    // (prev/play/next) and lockscreen action buttons (Suspend/Reboot/…).
    property int actionButtonSize: 45

    // Wallpaper picker grid (cell already includes Theme.margin padding).
    property int wallpaperCellWidth: 205
    property int wallpaperCellHeight: 140

    // Keybind cheatsheet — the key-combo column in each row.
    property int keybindKeyColumnWidth: 240

    // Lockscreen layout. The lockscreen runs as its own Quickshell
    // instance but shares this theme file through a relative symlink,
    // so these constants are available there too.
    property int lockContentWidth: 420          // inner column width
    property int lockClockHeight: 60             // clock row height (room around the display font)
    property int lockStatusHeight: 20           // small status rows under the clock
    property int lockActionSpacing: 45          // gap between action buttons
    property int lockActionColumnWidth: 60      // each action's column (button + label)
    property int lockFpButtonWidth: 30           // fingerprint toggle next to password
    property int lockFpReserve: 40              // password box reserves this when fp enabled
    property int lockInputLetterSpacing: 10     // password field letter spacing
}
