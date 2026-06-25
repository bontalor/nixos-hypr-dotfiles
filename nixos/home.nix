{ config, pkgs, inputs, ... }:

{
    home.username = "bonta";
    home.homeDirectory = "/home/bonta";
    home.stateVersion = "26.05";

    # XDG dirs
    xdg.userDirs = {
        enable = true;
        documents = "$HOME/documents";
        pictures = "$HOME/pictures";
        videos = "$HOME/videos";
        music = "$HOME/music";
        download = "$HOME/downloads";
    };

    # X11 / XWayland
    xresources.properties = {
        "Xft.dpi" = 144;
    };
    home.pointerCursor = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
        size = 24;
        gtk.enable = true;
        x11.enable = true;
        x11.defaultCursor = "Adwaita";
    };

    # Services
    services.mako.enable = true;

    # Scripts
    home.file.".local/bin/setwall" = {
        source = ./scripts/setwall;
        executable = true;
    };

    # Packages
    home.packages = with pkgs; [
        tree
        fastfetch
        chatterino2
        discord
	webcord
	spotify
	qbittorrent
        vesktop
        python3
        tree-sitter
        qmk_hid
        wmenu
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
        kdePackages.okular
        kdePackages.ark
        libnotify
	temurin-jre-bin-21
        hyprshot
        hyprpicker
        qtengine
	qt6.qtwayland
        wl-clipboard
        xrandr
        opencode
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
	xvfb
	cava
	lavat
	evtest
	ydotool
	theclicker
        # (pkgs.symlinkJoin {
        #     name = "spotify";
        #     paths = [ pkgs.spotify ];
        #     nativeBuildInputs = [ pkgs.makeWrapper ];
        #     postBuild = ''
        #         wrapProgram $out/bin/spotify \
        #             --unset DISPLAY \
        #             --add-flags "--ozone-platform-hint=wayland" \
        #             --add-flags "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
        #     '';
        # })
    ];

    # Session
    home.file.".local/share/emoji-test.txt".source =
	"${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt";

    # Programs
    programs.firefox = {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
    };

    programs.quickshell = {
	enable = true;
	systemd.enable = true;
    };
}
