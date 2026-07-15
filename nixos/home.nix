{ config, pkgs, inputs, ... }:

{
    home.username = "bonta";
    home.homeDirectory = "/home/bonta";
    home.stateVersion = "26.05";

# Imports

    imports = [
	inputs.spicetify-nix.homeManagerModules.spicetify
    ];

# XDG dirs
    xdg.userDirs = {
	enable = true;
	desktop = "HOME/desktop";
	documents = "$HOME/documents";
	pictures = "$HOME/pictures";
	videos = "$HOME/videos";
	music = "$HOME/music";
	download = "$HOME/downloads";
	publicShare = "$HOME/public";
    };

# X11 / XWayland
    xresources.properties = {
	"Xft.dpi" = 144;
    };
    home.pointerCursor = {
	enable = true;
	name = "Adwaita";
	package = pkgs.adwaita-icon-theme;
	size = 24;
	gtk.enable = true;
	x11.enable = true;
	x11.defaultCursor = "Adwaita";
    };

# Services
#services.mako.enable = true;

# Scripts (live symlink, no rebuild needed on edit)
    home.file.".local/bin/setwall".source =
	config.lib.file.mkOutOfStoreSymlink "/etc/nixos/scripts/setwall";

# Packages
    home.packages = with pkgs; [
	tree
	    fastfetch
	    chatterino2
	    discord
	    spotify
	    vesktop
	    qbittorrent
	    python3
	    tree-sitter
	    qmk_hid
	    brightnessctl
	    htop
	    awww
	    pywal16
	    pywalfox-native
	    kdePackages.dolphin
	    kdePackages.kio
	    kdePackages.kio-fuse
	    kdePackages.kio-extras
	    kdePackages.kservice
	    kdePackages.ffmpegthumbs
	    kdePackages.qtsvg
	    kdePackages.breeze
	    klassy
	    kdePackages.okular
	    kdePackages.ark
	    kdePackages.qtdeclarative
	    libnotify
	    temurin-jre-bin-21
	    hyprshot
	    hyprpicker
	    hypridle
	    qtengine
	    qt6.qtwayland
	    wl-clipboard
	    cliphist
	    xrandr
	    opencode
	    claude-code
	    github-copilot-cli
	    unicode-emoji
	    mpv
	    imv
	    waywall
	    glfw3-minecraft
	    libarchive
	    gearlever
	    appimage-run
	    rofi
	    osu-lazer-bin
	    cava
	    lavat
	    evtest
	    ydotool
	    theclicker
	    quickemu
	    quickgui
	    clang-tools
	    lua-language-server
	    bash-language-server
	    nixd
	    ffmpeg
	    helvum
	    spice-gtk
	    ];

# Session
    home.file.".local/share/emoji-test.txt".source =
	"${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt";

# Programs

    systemd.user.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    programs.firefox = {
	enable = true;
	configPath = "${config.xdg.configHome}/mozilla/firefox";
    };
}
