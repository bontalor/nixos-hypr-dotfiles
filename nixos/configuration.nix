{ pkgs, inputs, ... }:

let
mcsrPkgs = inputs.mcsr-nixos.packages.${pkgs.stdenv.hostPlatform.system};
in

{
    imports = [
	./hardware-configuration.nix
    ];

# Boot / Kernel
    boot.loader.grub.enable = true;
    boot.loader.grub.efiSupport = true;
    boot.loader.grub.device = "nodev";
    boot.loader.grub.useOSProber = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_latest;
    boot.kernelParams = [
	"threadirqs"
	    ''acpi_osi="!Windows 2015"''
	    "uinput"
    ];

# Hardware
    hardware.graphics = {
	enable = true;
	enable32Bit = true;
    };
    hardware.nvidia.open = true;
    hardware.nvidia.modesetting.enable = true;
    hardware.nvidia.powerManagement = {
	enable = true;
	kernelSuspendNotifier = true;
    };
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = false;
    hardware.opentabletdriver = {
	enable = true;
    };

# Services
    services.xserver.videoDrivers = [ "nvidia" ];
    services.printing.enable = true;
    services.pipewire = {
	enable = true;
	audio.enable = true;
	pulse.enable = true;
	jack.enable = true;
	alsa.enable = true;
	wireplumber.enable = true;
    };
    services.upower.enable = true;
    services.power-profiles-daemon.enable = true;
    services.openssh.enable = true;
    services.udisks2.enable = true;
    services.udev.extraRules = ''
	SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666"
	SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="102b", MODE="0666"
	'';

# Networking
    networking.hostName = "lor-nixos";
    networking.networkmanager.enable = true;

# Security
    security.rtkit.enable = true;
    security.pam.loginLimits = [
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "@audio"; item = "rtprio";  type = "-"; value = "99"; }
    { domain = "@audio"; item = "nice";    type = "-"; value = "-19"; }
    ];

# Time / Console
    time.timeZone = "America/New_York";
    console = {
	packages = [ pkgs.terminus_font ];
	font = "ter-v32b";
    };

# Programs
    programs.bash.enable = true;
    programs.bash.loginShellInit = ''
	if [ "$(tty)" = "/dev/tty1" ]; then
	    exec start-hyprland
		fi
		'';
    programs.zsh.enable = true;
    programs.zsh.loginShellInit = ''
	if [ "$(tty)" = "/dev/tty1" ]; then
	    exec start-hyprland
		fi
		'';

    programs.hyprland = {
	enable = true;
    };

    programs.appimage.enable = true;
    programs.appimage.binfmt = true;
    programs.appimage.package = pkgs.appimage-run.override {
	extraPkgs = pkgs: [
	    pkgs.curl
		pkgs.libmpg123
	];
    };

    programs.steam = {
	enable = true;
	protontricks.enable = true;
	extraCompatPackages = with pkgs; [
	    proton-ge-bin
	];
    };

    programs.obs-studio = {
	enable = true;
	package = (
		pkgs.obs-studio.override {
		cudaSupport = true;
		}
		);
    };

# Users
    users.users.bonta = {
	isNormalUser = true;
	shell = pkgs.zsh;
	extraGroups = [ "wheel" "video" "input" "audio" ];
    };

# XDG
    xdg.portal = {
	extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    };

# Environment
    environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];
    environment.sessionVariables = {
	NIXOS_OZONE_WL = "1";
    };
    environment.etc."xdg/menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
    environment.systemPackages = with pkgs; [
	neovim
	    wget
	    foot
	    git
	    jq
	    libarchive
	    xrdb
	    gcc
	    ripgrep
	    fd
	    fontconfig
	    icu
	    mcsrPkgs.ninjabrain-bot
	    (pkgs.prismlauncher.override {
	     jdks = [ mcsrPkgs.graalvm-21 jdk25 javaPackages.compiler.temurin-bin.jdk-25 ];
	     textToSpeechSupport = false;
	     })
    ];

# Fonts
    fonts.enableDefaultPackages = false;
    fonts.packages = with pkgs; [
	nerd-fonts.jetbrains-mono
	    noto-fonts
	    noto-fonts-lgc-plus
	    noto-fonts-cjk-sans
	    noto-fonts-cjk-serif
	    twitter-color-emoji
    ];
    fonts.fontconfig.enable = true;
    fonts.fontconfig.defaultFonts.emoji = [ "Twitter Color Emoji" ];

# Filesystems
    fileSystems."/mnt/koala" = {
	device = "/dev/disk/by-uuid/2b8abe19-0d7a-41ee-9002-6458836551c7";
	fsType = "ext4";
	options = [ "defaults" "nofail" ];
    };

# Nix
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nixpkgs.config.allowUnfree = true;
# stupid fucking pnpm temp fix
    nixpkgs.overlays = [
	(final: _prev: {
	 pnpm_10_29_2 = final.pnpm_10;
	 })
    ];



# System
    system.stateVersion = "26.05";
}
