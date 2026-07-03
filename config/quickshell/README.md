# quickshell config

A [Quickshell](https://quickshell.org) desktop shell — bar, panels, launcher,
notification daemon, OSD, and lockscreen — for NixOS + Hyprland. Themed by the
pywal cache, so colors follow the wallpaper.

## Layout

| Directory | Contents |
|---|---|
| `shell.qml` | Root scope: bar, popups, one declaration per panel, IPC handlers |
| `bar/` | Bar window and its widgets (workspaces, media, clock, tray, …) |
| `theme/` | Shared scaffolds (`Panel`, `SearchPanel`) and primitives (`ThemeText`, `PanelRow`, …), plus the `Theme`/`Colors`/`Panels`/`Icon` singletons |
| `models/` | D-Bus-backed state singletons (`NetworkModel`, `BatteryModel`, `PowerActions`) |
| `util/` | Pure-function singletons (`Scroll`, `FormatUtil`, `CalendarUtil`, `MoonUtil`, `SubstringRankSort`), `Paths`, `PrefStore`, `MprisSelector` |
| feature dirs | One directory per panel/feature (`volume/`, `network/`, `weather/`, `media/`, `notifications/`, `osd/`, `lockscreen/`, …) |

Conventions: state lives in singletons, views stay thin, panels build on the
`theme/` scaffolds, and native Quickshell services are used wherever they
exist — shell-outs are limited to real API gaps and each carries a comment
saying why.

## Running

The main shell is the default config (`quickshell` with no arguments).
Validate changes by watching `qs log` across a hot reload.

The lockscreen runs as a separate instance:

```sh
quickshell -p ~/.config/quickshell/lockscreen/shell.qml   # real session lock
quickshell -p ~/.config/quickshell/lockscreen/test.qml    # UI test, no lock
```

## Hyprland integration

Panels toggle via IPC — bind these in the Hyprland config:

```sh
qs ipc call overlay toggle <name>   # launcher, volume, network, battery,
                                    # datetime, weather, media, emoji,
                                    # notifications, settings, powermenu, picker
qs ipc call osd volumeUp|volumeDown|mute|brightnessUp|brightnessDown
```

Panels open as regular windows (`FloatingWindow`, titled "Network Control",
"Settings", …), so Hyprland window rules control their float/center behavior.
The bar, popups, and OSD are layer-shell surfaces (namespaces `quickshell:bar`,
`quickshell:notification`, `quickshell:osd`, `quickshell:tray`).

## Runtime dependencies

Declare these in the home-manager module / system config:

| Dependency | Used by | Required |
|---|---|---|
| quickshell ≥ 0.3.0, Qt 6 | everything | yes |
| JetBrainsMono Nerd Font | all text and glyphs (`Theme.fontFamily`) | yes |
| pywal cache (`~/.cache/wal/`) | `Colors`, lockscreen wallpaper | yes |
| python3 | `media/spectrum.py` visualizer | yes (stdlib only) |
| `pw-record`, `pw-dump`, `pw-cli` (PipeWire) | visualizer, device profiles | yes |
| `notify-send` (libnotify) | reload notification | yes |
| `wl-copy` (wl-clipboard) | emoji picker | for emoji |
| `brightnessctl` | brightness OSD | for brightness |
| `foot` + `nmtui` (NetworkManager) | network panel fallback | for that row |
| `fprintd` (`fprintd-verify`) | lockscreen fingerprint unlock | optional |
| power-profiles-daemon | battery panel profiles | optional |

## External inputs (`util/Paths.qml`)

| Path | Purpose |
|---|---|
| `~/walls/` | wallpaper picker source directory |
| `~/.local/bin/setwall` | script the picker invokes to apply a wallpaper |
| `~/.local/share/emoji-test.txt` | Unicode emoji data for the picker |
| `~/.cache/wal/colors.json`, `~/.cache/wal/wal` | pywal palette + wallpaper path |

## Preferences

User preferences persist in `$XDG_STATE_HOME/quickshell/prefs.json` (via
`util/PrefStore.qml`) — never in this config tree, which may be a read-only
home-manager symlink. The lockscreen instance shares the same file. Add a new
pref by declaring it on PrefStore's adapter and binding consumers to
`PrefStore.<name>`.
