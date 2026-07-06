# Quickshell config

A [Quickshell](https://quickshell.org/) desktop shell for Hyprland on NixOS,
run as a systemd user service. Bar, 15 toggleable panels, notification
daemon, OSD, clipboard history, and a session lockscreen — ~8k lines of QML.

Design goals: minimal, simple, readable, modular, and Quickshell-native
components wherever 0.3.0 provides one. Every remaining subprocess is a
documented gap in the native API (see "Runtime dependencies" below).

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
                    BatteryModel, PowerActions)
util/             Non-UI helpers (PrefStore, Paths, CheckedProcess, …)
bar/              Bar window + bar/widgets/* chips
<feature>/        One directory per panel/daemon: network/, volume/, media/,
                    weather/, clipboard/, notifications/, osd/, power/, …
lockscreen/       Separate Quickshell instance (see below)
```

Conventions:

- **Panels self-register.** A panel is one declaration in `shell.qml`
  (`NetworkPanel { panelKey: Panels.network }`); the scaffold registers it
  with the `Panels` singleton, which also feeds the launcher's synthetic
  entries. No registration list to keep in sync.
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
  read-only home-manager symlink. The Settings panel is the UI for it.
- **Timers are gated** on visibility or pending work so the shell idles.

## IPC surface (Hyprland binds)

```
qs ipc call overlay toggle <panel>    # panel keys: see components/Panels.qml
qs ipc call osd volumeUp|volumeDown|mute|micMute|brightnessUp|brightnessDown
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

The systemd user service must have these on its PATH (on NixOS: add the
packages to the unit's `path`/`Environment=PATH`, or to `home.packages` if
the unit inherits the session environment):

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
