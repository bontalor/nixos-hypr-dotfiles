pragma Singleton

import QtQuick
import Quickshell
import "../util"

// Centralized visual theme. Single source of truth for fonts, sizes, alphas,
// and panel geometry. Add shared visual constants here; domain tunables
// (refresh intervals, history caps, thresholds) live on their domain
// singleton (NotifDaemon, ClipboardModel, BatteryModel, OsdModel, …) —
// only constants used across domains stay here.

Singleton {
// --- Fonts (see the bottom of this file for full font config + PrefStore binding) ---

    // --- Bar geometry ---
    // `readonly` so an accidental external write (`Theme.barHeight = 100`)
    // can't silently mutate global geometry. Tweak the literal here.
    readonly property int barHeight: 30
    readonly property int barMargin: 10
    // Fallback width for content-only WidgetButtons (no `label`):
    // sized to the bar height so an icon-only button (SystemTray
    // chevron, WorkspacesWidget slots) is a clean square. Override
    // per-instance via `width:` if content needs more room.
    readonly property int widgetButtonWidth: barHeight
    // Tray icons shown inline before overflowing into the dropdown.
    readonly property int trayMaxVisible: 3
    // Workspaces always shown in the bar. The bar reserves these 9 slots
    // regardless of how many workspaces Hyprland currently reports, so
    // the bar is usable as soon as the surface maps (Hyprland may report
    // fewer than 9 until workspaces are explicitly created). Clicking a
    // slot below the live count focuses (creating) that workspace.
    readonly property int workspacesMin: 9

    // --- Panel geometry ---
    readonly property int panelWidth: 850
    readonly property int panelHeight: 450
    readonly property int margin: 10
    readonly property int colSpacing: 10

    // Popups (notifications, OSD). Smaller than panels. The `+ margin`
    // popup*WithShadow values account for the DropShadow pair extending
    // right/below — consumers size the PanelWindow to the WithShadow
    // value and the inner content to the plain value.
    readonly property int popupWidth: 270
    readonly property int popupHeight: 90
    readonly property int popupWidthWithShadow: popupWidth + margin
    readonly property int popupHeightWithShadow: popupHeight + margin

    // Two-pane scaffold (see components/Panel.qml)
    readonly property int rowHeight: 45
    readonly property int headerHeight: 30
    readonly property int subHeaderHeight: 20   // SectionSubHeader rows ("My devices", …)

    // Search-list scaffold (Launcher/EmojiPicker/PowerMenu)
    readonly property int searchRowHeight: 30
    readonly property int searchRowStride: searchRowHeight + margin
    readonly property int iconSize: 22

    // --- Alphas ---
    readonly property real alphaBackground: 0.75     // Qt.alpha(Colors.surface, 0.75)
    readonly property real alphaSelected: 0.75       // Qt.alpha(Colors.selected, 0.75)
    readonly property real alphaSectionHeader: 0.75  // Qt.alpha(Colors.accent, 0.75)
    readonly property real alphaHover: 0.25          // Qt.alpha(Colors.foreground, alphaHover) — bar widget hover
    readonly property real alphaWindow: 0.76         // Qt.alpha(Colors.background, alphaWindow) — bar/popup solid bg
    readonly property real alphaInactive: 0.25       // Qt.alpha(Colors.foreground, alphaInactive) — unlit meter dots / empty bar track
    readonly property real alphaDim: 0.5             // Qt.alpha(Colors.foreground, alphaDim) — dimmed metadata text

    // --- Audio visualizer (shared by media/SpectrumModel, VolumePanel,
    // and the bar's MediaWidget) ---
    // peakFps drives both the spectrum helper's frame rate (spectrum.py
    // restarts with the new value on reload) and VolumePanel's meters.
    readonly property int peakFps: 16
    readonly property int peakBands: 15
    readonly property real peakDecay: 0.05

    // Volume step per key/scroll tick (bar widget, VolumePanel, OSD).
    readonly property real volumeStep: 0.05

    // Small meter thickness / segmented-dot size. Used by:
    //   - OSD popup value bar (osd/OsdPopup.qml)
    //   - FFmpeg progress bar (ffmpeg/FfmpegPanel.qml)
    //   - Volume bars + peak dots (volume/AudioDeviceRow.qml)
    //   - Wi-Fi signal dots (network/NetworkPanel.qml)
    //   - Media seek bar (media/MediaPanel.qml)
    // Keeps the segmented-meter look uniform across the shell.
    readonly property int meterHeight: 10
    readonly property int marqueeSpeed: 25       // ms per pixel — lower is faster

    // --- Per-domain display sizes (hoisted for centralized tuning) ---
    //
    // These belong to one domain each (not "shared across domains"),
    // but live here so the visual rhythm of the shell stays tunable
    // from a single file rather than scattered as magic numbers.
    //
    // Media now-playing UI.
    readonly property int albumArtSize: 220          // square album art in MediaPanel
    // Square icon-button size. Used across domains: media transport
    // (prev/play/next) and lockscreen action buttons (Suspend/Reboot/…).
    readonly property int actionButtonSize: 45

    // Wallpaper picker grid (cell already includes Theme.margin padding).
    readonly property int wallpaperCellWidth: 205
    readonly property int wallpaperCellHeight: 140

    // Keybind cheatsheet — the key-combo column in each row.
    readonly property int keybindKeyColumnWidth: 240

    // Lockscreen layout. The lockscreen runs as its own Quickshell
    // instance but shares this theme file through a relative symlink,
    // so these constants are available there too.
    readonly property int lockContentWidth: 420          // inner column width
    readonly property int lockClockHeight: 60             // clock row height (room around the display font)
    readonly property int lockStatusHeight: 20           // small status rows under the clock
    readonly property int lockActionSpacing: 45          // gap between action buttons
    readonly property int lockActionColumnWidth: 60      // each action's column (button + label)
    readonly property int lockFpButtonWidth: 30           // fingerprint toggle next to password
    readonly property int lockFpReserve: 40              // password box reserves this when fp enabled
    readonly property int lockInputLetterSpacing: 10     // password field letter spacing

    // --- Lockscreen panel backdrop blur ---
    // Only the central lock panel is frosted — the surrounding wall
    // stays sharp (see LockSurface.qml). Hyprland's `layerrule = blur`
    // can't reach ext-session-lock-v1 surfaces, so the blur lives in
    // the QtQuick scene via QtQuick.Effects.MultiEffect applied as
    // `layer.effect` on a panel-anchored Item.
    //
    // Tuned to mirror the user's Hyprland blur settings:
    //   size=8, passes=3, noise=0, contrast=1, brightness=1, vibrancy=1, xray=true
    //
    // Hyprland's effective blur radius for `size=N, passes=P` is
    // `√P × N` for the principal gaussian, but its kernel is iterated
    // P times with the `size` parameter sampled at each iteration, so
    // visually it reads closer to `N × P` (24 px for size=8 passes=3).
    // MultiEffect only does one Gaussian pass on a single `blur`
    // (0..1) × `blurMax` radius; to match Hyprland's iterated kernel
    // visually, push `blurMax` to the Qt 6 cap (64) and `blur` toward
    // the top of its scale. The previous 0.45×32 ≈ 14.4 px setting
    // matched Hyprland's *theoretical* σ but looked noticeably weaker
    // in practice.
    property real lockWallpaperBlur: 0.65          // 0..1 multiplier × blurMax
    property int  lockWallpaperBlurMax: 64         // px cap; Qt 6.11 MultiEffect clamps >32 but accepts the value
    property real lockWallpaperBlurMultiplier: 1.0 // kernel multiplier (kept unity; tune for triple-pass feel)
    // Unity model: 0 = unchanged (matches Hyprland brightness/contrast/
    // vibrancy all at 1 and noise at 0). Tweak only if a busy wall
    // needs extra taming; the panel Rectangle's alphaWindow tint
    // already pulls the backdrop dark.
    property real lockWallpaperBrightness: 0.0    // -1..1 (0 = unchanged)
    property real lockWallpaperContrast: 0.0      // -1..1 (0 = unchanged)
    property real lockWallpaperSaturation: 0.0    // -1..1 (0 = unchanged)

    // --- Fonts ---
    // `fontFamily` is the main UI face and is User-overridable via the
    // Settings → Appearance "Text font" pref (PrefStore.fontFamily). It
    // does NOT need to be a Nerd Font — icon glyphs route through
    // `iconFamily` regardless (see ThemeText.qml), so a user can run the
    // whole shell on a non-nerd font (Cantarell, Inter, Noto Sans, …)
    // and still see every Icon.* glyph.
    property string defaultFontFamily: "JetBrainsMono Nerd Font"
    property string fontFamily: PrefStore.fontFamily || defaultFontFamily
    // Dedicated Nerd Font for Icon.* glyphs. Always a Nerd Font so the
    // glyphs render even when `fontFamily` is set to a non-nerd face;
    // users with `Symbols Nerd Font Mono` installed may prefer that —
    // keep this one so the default install "just works".
    property string iconFamily: "JetBrainsMono Nerd Font"
    property int fontPixelSize: 15
    property int fontPixelSizeLarge: 22
    property int fontPixelSizeXLarge: 30
    property int fontPixelSizeHeader: 24       // mid-emphasis (date line in DateTimePanel)
    property int fontPixelSizeDisplay: 32      // large display (lockscreen clock, weather temps)
    property int fontPixelSizeSmall: 12
}
