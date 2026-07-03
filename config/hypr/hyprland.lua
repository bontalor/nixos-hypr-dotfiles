---- MONITORS ----

hl.monitor({
    output   = "DP-2",
    mode     = "1920x1080@144.000",
    position = "1600x0",
    scale    = "1",
    vrr      = 0,
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
local fileManager = "dolphin"
local menu        = "bash ~/.config/hypr/wmenu.sh"
local snip        = "bash ~/.config/hypr/snip.sh"
local picker      = "bash ~/.config/hypr/picker.sh"
local wallpaper   = "qs ipc call overlay toggle picker"
local launcher    = "qs ipc call overlay toggle launcher"
local power       = "qs ipc call overlay toggle powermenu"
local volume      = "qs ipc call overlay toggle volume"
local network     = "qs ipc call overlay toggle network"
local battery     = "qs ipc call overlay toggle battery"
local emoji       = "qs ipc call overlay toggle emoji"

---- AUTOSTART ----

hl.on("hyprland.start", function()
    hl.exec_cmd("xrandr --output DP-2 --primary")
    hl.exec_cmd("kbuildsycoca6")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("awww-daemon --no-cache")
    hl.exec_cmd("~/.local/bin/setwall ~/walls/")
    hl.exec_cmd("systemctl --user start quickshell.service")
end)

---- AUTOSTOP ----

hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop quickshell.service")
end)

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
--hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

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
        10,
        20,
        20,
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
        vfr = false,
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
    },
})

---- KEYBINDINGS ----

local mainMod = "SUPER"
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal), { repeating = true })
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill())
hl.bind(mainMod .. " + M",
    hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + Z", hl.dsp.window.float({ action = "toggle" }), { repeating = true })
hl.bind(mainMod .. " + A", hl.dsp.window.fullscreen({ mode = "maximized" }), { repeating = true })
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }), { repeating = true })
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(launcher))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(power))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(picker))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(emoji))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(wallpaper))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(volume))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(network))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(battery))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("hyprshot --freeze -m region --clipboard-only"),
    { locked = true, repeating = true })
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }), { repeating = true })
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }), { repeating = true })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { repeating = true })
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }), { repeating = true })
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }), { repeating = true })
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }), { repeating = true })
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }), { repeating = true })
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.swap({ direction = "left" }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.swap({ direction = "left" }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.swap({ direction = "right" }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.swap({ direction = "up" }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.swap({ direction = "up" }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.swap({ direction = "down" }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.swap({ direction = "down" }), { repeating = true })
hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.move({ direction = "left" }), { repeating = true })
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.move({ direction = "left" }), { repeating = true })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ direction = "right" }), { repeating = true })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.move({ direction = "right" }), { repeating = true })
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.move({ direction = "up" }), { repeating = true })
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.move({ direction = "up" }), { repeating = true })
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.move({ direction = "down" }), { repeating = true })
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.move({ direction = "down" }), { repeating = true })
for i = 1, 9 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "+1" }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "-1" }), { repeating = true })

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
-- TODO: add bind to reset resize
hl.bind(mainMod .. " + comma", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + period", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + minus", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
hl.bind(mainMod .. " + equal", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("qs ipc call osd volumeUp"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("qs ipc call osd volumeDown"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("qs ipc call osd mute"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("qs ipc call osd brightnessUp"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs ipc call osd brightnessDown"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

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
        title =
        "Wallpaper Picker|App Launcher|Power Menu|Volume Control|Network Control|Battery & Power|Date & Time|Weather|Media|Emoji Picker|Notifications|Settings"
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
