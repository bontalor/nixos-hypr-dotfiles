# Quickshell config

A [Quickshell](https://quickshell.org/) desktop shell for Hyprland, run as a
systemd user service. Bar, 15 toggleable panels, notification daemon, OSD,
clipboard history, and a session lockscreen — ~8k lines of QML.

Design goals: minimal, simple, readable, modular, and Quickshell-native
components wherever 0.3.0 provides one. Every remaining subprocess is a
documented gap in the native API (see "Runtime dependencies" below).

Tested on Hyprland. Should run anywhere Quickshell 0.3.0, Qt 6.11, and the
runtime deps below are available — bring your own init system, distro, and
package manager.

## Layout

```
shell.qml         Root scope: bar + popups + daemons + one line per panel
dev.qml           Single-panel dev harness: LOR_PANEL=weather qs -p dev.qml
components/       Reusable UI framework (not theme values):
                    Panel        two-pane scaffold (sidebar sections + content)
                    PanelNav     keyboard/selection state machine for Panel
                    SearchPanel  search-list scaffold (launcher-style panels)
                    Panels       in-process panel registry (toggle/hideAll)
                    + row/label/popup/shadow building blocks
theme/            Visual constants only: Theme (sizes/fonts/alphas),
                    Colors (pywal-backed palette), Icon (glyph codepoints)
models/           Shared D-Bus-backed state singletons (NetworkModel,
                    BluetoothModel, BatteryModel, PowerActions)
util/             Non-UI helpers (PrefStore, Paths, CheckedProcess, …)
bar/              Bar window + bar/widgets/* chips
<feature>/        One directory per panel/daemon: network/, volume/, media/,
                    weather/, clipboard/, notifications/, osd/, power/, …
lockscreen/       Separate Quickshell instance (see below)
components/DropdownRow.qml
                  Canonical per-row dropdown scaffold; every clickable row
                    in every panel (Wi-Fi/Ethernet/Battery devices + Power
                    Profiles/Volume streams + devices/NetworkManager toggles/
                    FFmpeg operations/Job cancel) opens a small action list
                    below the header on click. State + close/toggle/trigger
                    + keyboard nav live on the shared DropdownState QtObject;
                    each panel supplies only rowActions(idx) (per-section
                    action list) + triggerAction(idx, actIdx) (performs the
                    selected action). Bluetooth stays on the panel-level
                    ConfigExpandItem/expandSection path; VolumePanel extends
                    the in-row DropdownRow via AudioDeviceRow.
```

Conventions:

- **Panels self-register.** A panel is one declaration in `shell.qml`
    (`NetworkPanel { panelKey: Panels.network }`); the scaffold registers
    it with the `Panels` singleton, which also feeds the launcher's
    synthetic entries. No registration list to keep in sync.
- **Every clickable panel row opens a dropdown.** Header click reveals a
    small action list below the row; click an action to perform it. The
    State + close/toggle/trigger + keyboard nav logic is shared on the
    `DropdownState` QtObject (`components/DropdownState.qml`); each panel
    supplies only the per-section `rowActions(idx)` and
    `triggerAction(idx, actIdx)` hooks. ConfigExpandItem sections
    (Volume / Settings / Bluetooth) keep their panel-level expandable path
    — the same pattern, just owned by PanelNav.
- **State lives in singletons, UI in windows.** Singletons consume native
  Quickshell services (Networking, Bluetooth, UPower, PowerProfiles,
  Pipewire, Mpris, Notifications, Pam, DesktopEntries, SystemClock) as live
  properties — no polling loops, no text parsing of CLI output.
- **Domain tunables live with their domain** (`NotifDaemon.notifHistoryMax`,
  `ClipboardModel.imageMaxBytes`, `BatteryModel.batteryCritical`,
  `OsdModel.hideInterval`, `WeatherModel.refreshMillis`). `theme/Theme.qml`
  holds only visual constants shared across domains.
- **Prefs** persist to `$XDG_STATE_HOME/quickshell/prefs.json` via
  `PrefStore` (FileView + JsonAdapter) — the config tree itself may be a
  read-only symlink from your dotfiles repo. The Settings panel is the UI
  for it.
- **Timers are gated** on visibility or pending work so the shell idles.
- **Singletons are declared in `qmldir`** in every shared directory
  (`theme/`, `models/`, `util/`, `components/`) and per-feature singleton
  directories (`notifications/`, `osd/`, `clipboard/`, `weather/`, `media/`,
  `time/`). Directory-import resolution marks them singleton for both the
  engine and `qmllint`, so the linter treats `Panels`, `NetworkModel`,
  `PrefStore`, etc. as singletons without false-positive warnings.

## IPC surface (Hyprland binds)

```
qs ipc call overlay toggle <panel>    # panel keys: see components/Panels.qml
qs ipc call osd volumeUp|volumeDown|mute|micMute|brightnessUp|brightnessDown
```

### Hyprland `hyprland.conf` snippets

Layer namespaces used by this shell:

| Window               | WlrLayershell namespace       |
|---|---|
| Bar                  | `quickshell:bar`              |
| Notifications popup  | `quickshell:notification`     |
| OSD popup            | `quickshell:osd`              |
| All panels (popover) | `quickshell:overlay`          |

Suggested rules (paste into `hyprland.conf`):

```
layerrule = blur,  quickshell:bar
layerrule = blur,  quickshell:overlay
layerrule = blur,  quickshell:notification
layerrule = blur,  quickshell:osd
layerrule = ignorezero, quickshell:bar
layerrule = ignorealpha 0.5, quickshell:bar
layerrule = animation slide, quickshell:overlay
```

Key binds (tweak the mods to taste; the panel keys match `Panels.*`):

```
bind = SUPER,       Return, exec, qs ipc call overlay toggle launcher
bind = SUPER,       V,      exec, qs ipc call overlay toggle clipboard
bind = SUPER,       N,      exec, qs ipc call overlay toggle notifications
bind = SUPER,       P,      exec, qs ipc call overlay toggle powermenu
bind = SUPER,       B,      exec, qs ipc call overlay toggle battery
bind = SUPER,       M,      exec, qs ipc call overlay toggle media
bind = SUPER,       E,      exec, qs ipc call overlay toggle emoji
bind = SUPER,       W,      exec, qs ipc call overlay toggle weather
bind = SUPER,       T,      exec, qs ipc call overlay toggle datetime
bind = SUPER SHIFT, V,      exec, qs ipc call overlay toggle volume
bind = SUPER SHIFT, N,      exec, qs ipc call overlay toggle network
bind = SUPER SHIFT, S,      exec, qs ipc call overlay toggle settings
bind = SUPER SHIFT, K,      exec, qs ipc call overlay toggle keybinds
bind = SUPER SHIFT, W,      exec, qs ipc call overlay toggle picker
bind = SUPER SHIFT, F,      exec, qs ipc call overlay toggle ffmpeg
bind = XF86AudioRaiseVolume, exec, qs ipc call osd volumeUp
bind = XF86AudioLowerVolume, exec, qs ipc call osd volumeDown
bind = XF86AudioMute,        exec, qs ipc call osd mute
bind = XF86AudioMicMute,     exec, qs ipc call osd micMute
bind = XF86MonBrightnessUp,   exec, qs ipc call osd brightnessUp
bind = XF86MonBrightnessDown, exec, qs ipc call osd brightnessDown
```

The lockscreen is its own instance (so a shell reload never unlocks the
screen) and is started by the PowerMenu "Lock" action:

```
quickshell -p ~/.config/quickshell/lockscreen/shell.qml
```

It shares `models/`, `theme/`, `util/`, and `components/` through relative
symlinks inside `lockscreen/` (Quickshell isolates each config root), and
reads the same `prefs.json` (fingerprint toggle, time format). PAM config
for password auth is `lockscreen/pam/password.conf`; fingerprint unlock
runs `fprintd-verify` concurrently with the password prompt.

## Runtime dependencies

The shell is launched as a systemd user service. Ensure the binaries below
are on the unit's `PATH` — on a distro that runs systemd user units under
the user session, inherit the user environment or add the packages you
install to the unit's `Environment=PATH` / `PATH` directive. On NixOS that
means `home.packages` or `systemd.user.services.quickshell.Service.Path`;
on Arch/Fedora/Debian it's just "install the package and confirm it's on
`$PATH` under the session that launches the unit."

| Dependency | Used by | Why not native |
|---|---|---|
| `wl-clipboard` (`wl-paste`, `wl-copy`) | clipboard history, emoji picker | `Quickshell.clipboardText` can't watch/own selections in 0.3.0 |
| `brightnessctl` | OSD brightness | no backlight service in 0.3.0 |
| `pw-dump`, `pw-cli` (pipewire) | VolumePanel device profiles | no device-profile API in 0.3.0 |
| `pw-record` (pipewire) | `media/spectrum.py` visualizer capture | — |
| `python3` (stdlib only) | `media/spectrum.py` FFT | no native spectrum source |
| `nmcli` | Wi-Fi connect with password, wired reconnect | not exposed by Quickshell.Networking |
| `ffmpeg`, `ffprobe` | FfmpegPanel (convert/trim/resize/compress/GIF/merge) | no media transcoding API |
| a terminal (default `foot`, Settings → System) | opening `nmtui` | — |
| `nmtui` (networkmanager) | Wi-Fi password entry / NM config | no secret-agent API |
| `fprintd-verify` (fprintd) | lockscreen fingerprint unlock | PamContext is text-only |
| `notify-send` (libnotify) | reload notification (via own daemon) | intentional round-trip |
| `systemctl`, `loginctl` | PowerMenu actions | no logind service in 0.3.0 |
| `bash`, `sh`, coreutils (`cat`, `rm`, `stat`, `mktemp`, `sha256sum`, `cut`), `curl`, `base64` | clipboard watchers / image copy | — |
| `~/.local/bin/setwall` | wallpaper Picker | user script (pywal + hyprpaper) |
| `~/.cache/wal/colors.json` (pywal) | Colors singleton | palette source, hot-reloaded |
| `~/.local/share/emoji-test.txt` | emoji picker | Unicode data file |
| JetBrainsMono Nerd Font | all text + glyph icons | `Theme.fontFamily` |

## Development

```
LOR_PANEL=<panels-key> qs -p dev.qml    # one panel, no bar/daemons
qs -p lockscreen/test.qml               # lockscreen UI in a window
```

## Todo

- ~~fix wallpaper picker not opening on the current wallpaper~~ — the
  picker now reads `~/.cache/wal/wal` (pywal's record of the applied
  wallpaper) at open, so an out-of-band `setwall` is reflected.
- ~~add numeric date to the date/time panel~~ — Date section shows a
  `M-D-YY` line under the long form (e.g. "7-12-26" for July 12, 2026).
- ~~volume panel dropdown per device~~ — playback/recording/sink/source
  rows open a Mute/Unmute + Set Default dropdown on Enter/click; default
  device stays colored and labeled, but Enter no longer silently swaps it.
- ~~notification panel: no chevrons + full text when expanded~~ — the
  down/up chevron is gone, and `maximumLineCount: 0` plus
  `elide: ElideNone` means truly long notifications unroll fully. Sender
  app icons (and the embedded image as fallback) now render in each row.
- ~~media panel: accurate progress bar~~ — the interpolation poll runs
  at 250 ms (was 1 s), the fill ratio is clamped to [0, 1] so a stale
  position during a seek/track-change can't overflow the bar, and seek
  clicks re-read `currentPlayer.position` at click time instead of the
  tick-stale bound value.
- ~~dropdowns for actionable rows across panels~~ — Wi-Fi (Connect /
  Disconnect / Forget), Ethernet (Connect / Disconnect), and Battery
  (Track this device) rows now share a `components/DropdownRow.qml`
  scaffold with the same keyboard nav as the existing ConfigExpandItem
  pattern.

- ~~dropdowns for actionable rows across panels~~ — extended to every
  clickable row in every panel (Power Profiles, Wi-Fi/BT/nmtui toggles,
  FFmpeg operations/job cancel). Shared state + close/toggle/trigger +
  keyboard nav live on `components/DropdownState.qml`; each panel
  supplies only `rowActions(idx)` + `triggerAction(idx, actIdx)` hooks.

## Improvements (audit pass)

- **BluetoothModel extracted** — BlueZ-backed state that was inlined in
  `network/NetworkPanel.qml` is now a singleton in `models/BluetoothModel.qml`,
  matching the `NetworkModel` / `BatteryModel` pattern. The panel is ~120
  LOC slimmer; the bar could surface a BT chip from this singleton later
  without reaching back into panel internals.
- **Lock spawn guard** — `models/PowerActions.qml`'s "Lock" command now
  checks `~/.local/state/quickshell/lock.pid` (written by
  `lockscreen/LockContext.qml` via `$PPID`) and `kill -0`s the recorded
  PID before spawning, so a stuck bind or repeated `Lock` press can't
  pile up lockscreen instances. Cleared on unlock. (Note: `$PPID` not
  `$$` — `$$` would be the spawning `sh`'s PID, which exits immediately.)
- **OSD brightness floor** — `OsdModel.brightnessDown` checks the cached
  current brightness and short-circuits / sets a 1% floor (`brightnessMin`)
  so a blind brightness-down mash can't drive the panel to 0% (which on
  most laptops blanks the screen — `brightnessctl s N%-` reduces by N%
  of *current* and silently approaches black).
- **Notification popup icons** — `NotifPopup.qml` now renders the sender
  app icon (with the embedded image as fallback) the same way the
  history panel does, instead of the previous fetch-only-no-display.
- **Default color fallback** — `theme/Colors.qml` initializes the
  palette to a Catppuccin-Mocha-aligned dark set instead of all-`#000000`,
  so a config reload while pywal's cache is missing/stale stays legible
  (semantic aliases like `selected=color1` were unreadable on a black
  surface). Mismatches with the active wal palette only last until the
  next `setwall`.
- **qmldir per directory** — every shared dir (`theme/`, `models/`,
  `util/`, `components/`) and every per-feature dir that contains a
  singleton (`notifications/`, `osd/`, `clipboard/`, `weather/`, `media/`,
  `time/`) now has a `qmldir` declaring its singletons and export types.
  `qmllint` no longer reports "Type X not declared as singleton" false
  positives against this config; the linter is now usable as a real
  check, invoked as:
  ```
  qmllint -I <path-to-Quickshell-qml> shell.qml
  ```
  (where `<path-to-Quickshell-qml>` is the directory containing
  `Quickshell/qmldir` for your installation — printed by `qs -v`
  / findable via your Qt 6 QML import path).
- **Dropdown pattern consolidated** — shared state and keyboard nav for
  every per-row action dropdown now live on the `DropdownState` QtObject
  (`components/DropdownState.qml`). Every clickable row in every panel
  (Battery devices, Power Profiles, Wi-Fi/Ethernet, Configuration
  toggles, NetworkManager, Volume streams + devices, every FFmpeg
  operation + Trim/Resize EditRows + Job cancel) opens an action list;
  ConfigExpandItem sections (Volume / Settings / Bluetooth config) keep
  the expandable-config path — same UX, owned by PanelNav. Each panel
  supplies only `rowActions(idx)` (per-section action list) and
  `triggerAction(idx, actIdx)` (performs the action); ~195 LOC of
  near-duplicate state + keyboard nav across four panels collapsed into
  a single ~95 LOC QtObject. The earlier "click a non-keyboard-highlighted
  row's action silently operated on the keyboard row" bug is fixed along
  the way: every click always moves `selDevice` to the clicked row.
- **Theme sizes consolidated to 10px / 45px rhythm** — every leftover
  per-domain hardcoded size is now expressed through a Theme constant:
  `meterHeight: 10` (thin track bars / segmented-dot size — OSD value,
  FFmpeg progress, Volume bars + peak dots, Wi-Fi signal dots, media seek
  bar), `margin: 10` (bar-track inner spacing, the seek bar's
  elapsed↔remaining margins, the Battery profile icon+name Row spacing),
  and `actionButtonSize: 45` (square action buttons + the elapsed/
  remaining text column widths beside the seek bar). The lockscreen's
  wallpaper `sourceSize` is removed so the shell renders at any screen
  resolution; the lockscreen no longer pins a 1920x1080 decode target.

## Development workflow notes

- `qmllint` (Qt 6.11) is now advisory-and-usable: with the per-directory
  `qmldir` files declaring singletons, past false-positive "Type X not
  declared as singleton" warnings are gone. Remaining warnings from
  `qmllint` should be investigated. The real check remains
  `qs -p dev.qml` for the panel you edited, plus `qs -p shell.qml` for
  whole-shell smoke.