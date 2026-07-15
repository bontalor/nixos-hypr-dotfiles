---- MONITORS ----

hl.monitor({
    output   = "DP-2",
    mode     = "1920x1080@144.000",
    position = "1600x0",
    scale    = "1",
    vrr      = 1,
})

hl.monitor({
    output   = "DP-1",
    mode     = "1600x900@60.000",
    position = "0x0",
    scale    = "1",
    vrr      = 0,
})


---- MY PROGRAMS ----

local terminal    = "foot"
local picker      = "bash ~/.config/hypr/picker.sh"
local snip        = "bash ~/.config/hypr/snip.sh"
local wallpaper   = "qs ipc call overlay toggle picker"
local launcher    = "qs ipc call overlay toggle launcher"
local power       = "qs ipc call overlay toggle powermenu"
local volume      = "qs ipc call overlay toggle volume"
local network     = "qs ipc call overlay toggle network"
local battery     = "qs ipc call overlay toggle battery"
local emoji       = "qs ipc call overlay toggle emoji"
local clipboard   = "qs ipc call overlay toggle clipboard"

---- AUTOSTART ----

hl.on("hyprland.start", function()
    hl.exec_cmd("xrandr --output DP-2 --primary")
    hl.exec_cmd("kbuildsycoca6")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("awww-daemon --no-cache")
    hl.exec_cmd("~/.local/bin/setwall ~/walls/")
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("quickshell")
end)

---- AUTOSTOP ----

---- ENVIRONMENT VARIABLES ----

-- nvidia slop
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- kde slop
--hl.env("XDG_MENU_PREFIX", "plasma-")
--hl.env("XDG_CURRENT_DESKTOP", "KDE")

-- portal detection
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")

-- make firefox file picker dolphin
hl.env("GTK_USE_PORTAL", "1")

hl.env("QT_QPA_PLATFORMTHEME", "qtengine")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- electron/wayland
hl.env("NIXOS_OZONE_WL", "1")

----- PERMISSIONS -----

hl.config({
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
        --     enforce_permissions = true,
    },
})

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

---- LOOK AND FEEL ----

hl.config({
    xwayland = {
        force_zero_scaling = true,
        use_nearest_neighbor = false,
    },
    general = {
        gaps_in  = 10,
        gaps_out = { top = 10, right = 20, bottom = 20, left = 10 },
        border_size      = 0,
        col              = {
            active_border = { colors = { "#000000" } },
            inactive_border = { colors = { "#000000" } },
        },
        resize_on_border = false,
        allow_tearing    = true,
        layout           = "dwindle",
    },

    decoration = {
        rounding_power   = 0,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow           = {
            enabled = true,
            color = "0xbf000000",
	    range = 0,
            sharp = true,
            offset = { 10, 10, },
        },
        blur             = {
            enabled = true,
            size = 8,
            passes = 3,
            noise = 0,
            contrast = 1,
            brightness = 1,
            vibrancy = 1,
            xray = true,
        },
    },
    animations = {
        enabled = false,
    },
})

hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
        force_split = 2,
    },
})

----  MISC  ----

hl.config({
    misc = {
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo    = true, -- If true disables the random hyprland logo / anime girl background. :(
        enable_swallow           = true,
    },
})

----  DEBUG  ----

hl.config({
    debug = {
	damage_tracking = 1, -- Fix weird hyprland shadow flickering bug
    },
})

---- INPUT ----

hl.config({
    input = {
        kb_layout               = "us",
        kb_variant              = "",
        kb_model                = "",
        kb_options              = "",
        kb_rules                = "",
        repeat_rate             = 40,
        repeat_delay            = 300,
        follow_mouse            = 1,
        sensitivity             = 0,
        scroll_factor           = 1,
        emulate_discrete_scroll = 0,
        accel_profile           = "flat",
        touchpad                = {
            natural_scroll = false,
        },
    },
})

hl.config({
    cursor = {
        default_monitor = "DP-2",
        no_break_fs_vrr = 1,
        min_refresh_rate = 144,
        no_hardware_cursors = 0,
	hide_on_key_press = false,
    },
})

---- KEYBINDINGS ----

-- Descriptions show in `hyprctl binds -j` and the shell's Keybinds
-- panel (lua binds otherwise list as an opaque "__lua <id>").
local mainMod = "SUPER"
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal), { repeating = true, description = "Terminal" })
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { repeating = true, description = "Close window" })
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill(), { description = "Kill window" })
hl.bind(mainMod .. " + M",
    hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"),
    { description = "Exit Hyprland" })
hl.bind(mainMod .. " + Z", hl.dsp.window.float({ action = "toggle" }), { repeating = true, description = "Toggle floating" })
hl.bind(mainMod .. " + A", hl.dsp.window.fullscreen({ mode = "maximized" }), { repeating = true, description = "Maximize window" })
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }), { repeating = true, description = "Toggle fullscreen" })
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(launcher), { description = "Toggle app launcher" })
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(power), { description = "Toggle power menu" })
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(picker), { description = "Color picker" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(emoji), { description = "Toggle emoji picker" })
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(wallpaper), { description = "Toggle wallpaper picker" })
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(volume), { description = "Toggle volume panel" })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(network), { description = "Toggle network panel" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(battery), { description = "Toggle battery panel" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(clipboard), { description = "Toggle clipboard history" })
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(snip), { locked = true, repeating = true, description = "Screenshot region to clipboard" })
local focusBinds = {
    { "left",  "left" }, { "H", "left" },
    { "right", "right" }, { "L", "right" },
    { "up",    "up" }, { "K", "up" },
    { "down",  "down" }, { "J", "down" },
}
for _, b in ipairs(focusBinds) do
    hl.bind(mainMod .. " + " .. b[1], hl.dsp.focus({ direction = b[2] }),
        { repeating = true, description = "Focus " .. b[2] })
    hl.bind(mainMod .. " + SHIFT + " .. b[1], hl.dsp.window.swap({ direction = b[2] }),
        { repeating = true, description = "Swap window " .. b[2] })
    hl.bind(mainMod .. " + CTRL + " .. b[1], hl.dsp.window.move({ direction = b[2] }),
        { repeating = true, description = "Move window " .. b[2] })
end
for i = 1, 9 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }),
        { description = "Focus workspace " .. i })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }),
        { description = "Move window to workspace " .. i })
end
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "+1" }), { repeating = true, description = "Next workspace" })
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "-1" }), { repeating = true, description = "Previous workspace" })

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Drag window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })
-- TODO: add bind to reset resize
hl.bind(mainMod .. " + comma", hl.dsp.window.resize({ x = -10, y = 0, relative = true }),
    { repeating = true, description = "Shrink window horizontally" })
hl.bind(mainMod .. " + period", hl.dsp.window.resize({ x = 10, y = 0, relative = true }),
    { repeating = true, description = "Grow window horizontally" })
hl.bind(mainMod .. " + minus", hl.dsp.window.resize({ x = 0, y = -10, relative = true }),
    { repeating = true, description = "Shrink window vertically" })
hl.bind(mainMod .. " + equal", hl.dsp.window.resize({ x = 0, y = 10, relative = true }),
    { repeating = true, description = "Grow window vertically" })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("qs ipc call osd volumeUp"),
    { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("qs ipc call osd volumeDown"),
    { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("qs ipc call osd mute"),
    { locked = true, repeating = true, description = "Mute audio" })
-- Through the shell's OSD (shows mic state) instead of raw wpctl.
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("qs ipc call osd micMute"),
    { locked = true, repeating = true, description = "Mute microphone" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("qs ipc call osd brightnessUp"),
    { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs ipc call osd brightnessDown"),
    { locked = true, repeating = true, description = "Brightness down" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })

---- WINDOWS AND WORKSPACES ----

-- Pin workspaces to monitors
for i = 1, 8 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor   = "DP-2",
    })
end

hl.workspace_rule({
    workspace = "9",
    monitor   = "DP-1",
})

hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    match = {
        float = true,
        class = "negative:^(steam)$",
    },
    size = { 850, 450 },
    center = true,
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name     = "fix-xwayland-drags",
    match    = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    match = { fullscreen = "true" }, immediate = true
})

hl.window_rule({
    name = "fullscreen-apps-prevent-suspend",
    match = {
        class = ".*"
    },
    idle_inhibit = "fullscreen"
})

--hl.window_rule({
--    name = "low-scroll-factor",
--    match = {
--        class = "discord|spotify|firefox"
--    },
--    scroll_mouse = 0.5,
--})

hl.window_rule({
    name = "quickshell-floating-windows",
    match = {
        --title = "Wallpaper Picker|App Launcher|Power Menu|Volume Control|Network Control|Battery & Power|Date & Time|Weather|Media|Emoji Picker|Notifications|Settings|Clipboard|Keybinds|FFmpeg"
	class = "org.quickshell"
    },
    float = true,
    size = { 850, 450, },
})

hl.layer_rule({
    match = { namespace = "quickshell:bar|quickshell:notification|quickshell:tray" },
    blur = true,
    ignore_alpha = 0.75,
    xray = true,
})
