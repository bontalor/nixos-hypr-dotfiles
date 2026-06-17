# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:

{
    imports =
	[ # Include the results of the hardware scan.
	./hardware-configuration.nix
	];
    hardware.graphics.enable = true;
    hardware.graphics.enable32Bit = true;
    hardware.nvidia.open = true;
    hardware.nvidia.modesetting.enable = true;
    services.xserver.videoDrivers = [ "nvidia" ];

# Use the systemd-boot EFI boot loader.
#boot.loader.systemd-boot = {
#  enable = true;
#  configurationLimit = 10;
#};
#boot.loader.efi.canTouchEfiVariables = true;

    boot.loader.grub.enable = true;
    boot.loader.grub.efiSupport = true;
    boot.loader.grub.device = "nodev";
    boot.loader.grub.useOSProber = true;
    boot.loader.efi.canTouchEfiVariables = true;

# Use latest kernel.
    boot.kernelPackages = pkgs.linuxPackages_latest;

    networking.hostName = "lor-nixos"; # Define your hostname.

# Realtime permissions
	security.rtkit.enable = true;

# Configure network connections interactively with nmcli or nmtui.
    networking.networkmanager.enable = true;

# Set your time zone.
    time.timeZone = "America/New_York";

# Configure network proxy if necessary
# networking.proxy.default = "http://user:password@proxy:port/";
# networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

# Select internationalisation properties.
# i18n.defaultLocale = "en_US.UTF-8";
    console = {
	packages = [ pkgs.terminus_font ];
	font = "ter-v32b";
#  keyMap = "us";
#  useXkbConfig = true; # use xkb.options in tty.
    };

# Enable the X11 windowing system.
# services.xserver.enable = true;


# Configure keymap in X11
# services.xserver.xkb.layout = "us";
# services.xserver.xkb.options = "eurosign:e,caps:escape";

# Environment Variables
    environment.sessionVariables = {
	NIXOS_OZONE_WL = "1";
    };
    fileSystems."/mnt" = {
	device = "/dev/disk/by-uuid/2b8abe19-0d7a-41ee-9002-6458836551c7";
	fsType = "ext4";
	options = [ "defaults" "nofail" ];
    };

# XDG stuff    
    environment.etc."xdg/menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
    xdg.portal = {
	enable = true;
	extraPortals = [
	    pkgs.kdePackages.xdg-desktop-portal-kde
		pkgs.xdg-desktop-portal-hyprland
	];
	config = {
	    hyprland = {
		"org.freedesktop.impl.portal.ScreenCast" = "hyprland";
		"org.freedesktop.impl.portal.Screenshot" = "hyprland";
	    };
	};
    };


# Enable CUPS to print documents.
    services.printing.enable = true;

# Enable bluetooth
    hardware.bluetooth = {
	enable = true;
	powerOnBoot = false;
    };

# Enable sound.
    services.pipewire = {
	enable = true;
	audio.enable = true;
	pulse.enable = true;
	jack.enable = true;
	alsa.enable = true;
	wireplumber.enable = true;
    };

    services.pipewire.extraConfig.pipewire."92-low-latency" = {
	"context.properties" = {
	    "default.clock.rate" = 48000;
	    "default.clock.quantum" = 64;
	    "default.clock.min-quantum" = 64;
	    "default.clock.max-quantum" = 64;
	};
    };

    services.pipewire.extraConfig.pipewire-pulse."92-low-latency" = {
	"context.properties" = [
	{
	    name = "libpipewire-module-protocol-pulse";
	    args = { };
	}
	];
	"pulse.properties" = {
	    "pulse.min.req" = "64/48000";
	    "pulse.default.req" = "64/48000";
	    "pulse.max.req" = "64/48000";
	    "pulse.min.quantum" = "64/48000";
	    "pulse.max.quantum" = "64/48000";
	};
	"stream.properties" = {
	    "node.latency" = "64/48000";
	    "resample.quality" = 1;
	};
    };

    services.pipewire.extraConfig.jack."92-low-latency" = {
	"context.properties" = [
	{
	    "default.clock.quantum-limit" = "64";
	}
	];
	"jack.properties" = {
	    "node.latency" = "64/48000";
	    "node.rate" = "1/48000";
	    "node.quantum" = "64/48000";
	};
    };
    services.pipewire.extraConfig.client."92-low-latency" = {
	"stream.properties" = {
	    "node.latency" = "64/48000";
	    "resample.quality" = 1;
	};
    };


# Enable touchpad support (enabled default in most desktopManager).
# services.libinput.enable = true;

# Enable battery support
    services.upower.enable = true;
    services.power-profiles-daemon = {
	enable = true;	
    };

# Enable fingerprint support
#services.fprintd.enable = true;

# Define a user account. Don't forget to set a password with ‘passwd’.
    users.users.bonta = {
	isNormalUser = true;
	shell = pkgs.zsh;
	extraGroups = [ "wheel" "video" "input" ]; # Enable ‘sudo’ for the user.
    };

    security.pam.loginLimits = [
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "@audio"; item = "rtprio";  type = "-"; value = "99"; }
    { domain = "@audio"; item = "nice";    type = "-"; value = "-19"; }
    ];

# Nix module programs
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
    environment.shells = with pkgs; [
	zsh
    ];

    programs.hyprland = {
	enable = true;
    };

# Enable nonfree (evil) packages
    nixpkgs.config.allowUnfree = true;

# List packages installed in system profile.
# You can use https://search.nixos.org/ to find more packages (and options).
    environment.systemPackages = with pkgs; [
	neovim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
	    wget
	    foot
	    git
	    libarchive
	    xrdb
	    gcc
	    ripgrep
	    fd
	    fontconfig
    ];

    fonts.enableDefaultPackages = false;

    fonts.packages = with pkgs; [
	nerd-fonts.jetbrains-mono
	    noto-fonts
	    noto-fonts-lgc-plus
	    noto-fonts-cjk-sans
	    noto-fonts-cjk-serif
	    twitter-color-emoji
    ];

    fonts.fontconfig = {
	enable = true;
	defaultFonts = {
	    emoji = [ "Twitter Color Emoji" ];
	};
    };

# Some programs need SUID wrappers, can be configured further or are
# started in user sessions.
# programs.mtr.enable = true;
# programs.gnupg.agent = {
#   enable = true;
#   enableSSHSupport = true;
# };

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

# List services that you want to enable:

# Enable the OpenSSH daemon.
    services.openssh.enable = true;

# dolphin show disks
    services.udisks2.enable = true;

# Open ports in the firewall.
# networking.firewall.allowedTCPPorts = [ ... ];
# networking.firewall.allowedUDPPorts = [ ... ];
# Or disable the firewall altogether.
# networking.firewall.enable = false;

# Copy the NixOS configuration file and link it from the resulting system
# (/run/current-system/configuration.nix). This is useful in case you
# accidentally delete configuration.nix.
# system.copySystemConfiguration = true;

# This option defines the first version of NixOS you have installed on this particular machine,
# and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
#
# Most users should NEVER change this value after the initial install, for any reason,
# even if you've upgraded your system to a new NixOS release.
#
# This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
# so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
# to actually do that.
#
# This value being lower than the current NixOS release does NOT mean your system is
# out of date, out of support, or vulnerable.
#
# Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
# and migrated your data accordingly.
#
# For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
    system.stateVersion = "26.05"; # Did you read the comment?

}

