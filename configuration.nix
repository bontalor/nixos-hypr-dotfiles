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

# Use the systemd-boot EFI boot loader.
#boot.loader.systemd-boot = {
#  enable = true;
#  configurationLimit = 10;
#};
#boot.loader.efi.canTouchEfiVariables = true;

    boot.loader.grub.enable = true;
    boot.loader.grub.efiSupport = true;
    boot.loader.grub.device = "nodev";
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.grub.useOSProber = false;
    boot.loader.grub.extraEntries = ''
	menuentry "NixOS-2" {
	    set root=(hd0,gpt1)
		chainloader /EFI/systemd/systemd-bootx64.efi
	}
    menuentry "Arch Linux" {
	set root=(hd0,gpt1)
	    chainloader /EFI/Linux/arch-linux.efi
    }
    menuentry "Omarchy" {
	set root=(hd0,gpt1)
	    chainloader /EFI/limine/limine_x64.efi
    }
    menuentry "Windows 11" {
	set root=(hd0,gpt1)
	    chainloader /EFI/Microsoft/Boot/bootmgfw.efi
    }
    '';


# Use latest kernel.
    boot.kernelPackages = pkgs.linuxPackages_latest;

    networking.hostName = "Lor-nixosfw"; # Define your hostname.

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

# Laptop lid close stuff from HELL
    services.logind.settings = {
	Login = {
	    HandleLidSwitch = "suspend";
	    HandleLidSwitchExternalPower = "suspend";
	    HandleLidSwitchDocked = "suspend"; # Ensures it suspends even if multi-monitor/docked
		LidSwitchIgnoreInhibited = "yes";  # Overrides apps trying to block suspend
		HoldoffTimeoutSec = "0";           # Removes the 30-second delay rule
	};
    };

# Disable specific USB wakeup triggers that cause instant wake loops
    services.udev.extraRules = ''
	ACTION=="add", SUBSYSTEM=="serio", DRIVERS=="atkbd", ATTR{power/wakeup}="disabled"
	SUBSYSTEM=="usb", ATTR{power/wakeup}="disabled"
	SUBSYSTEM=="i2c", ATTR{power/wakeup}="disabled"
	'';

# Alternative: Force clear the XHCI (USB) wakeup triggers on boot
    systemd.services.disable-usb-wakeup = {
	description = "Disable USB wakeup triggers to fix Framework 16 sleep loops";
	wantedBy = [ "multi-user.target" ];
	serviceConfig = {
	    Type = "oneshot";
	    ExecStart = "${pkgs.bash}/bin/bash -c 'echo XHC0 > /proc/acpi/wakeup || true'";
	    RemainAfterExit = true;
	};
    };

    boot.kernelParams = [
	"iommu=pt"
	    "pcie_aspm=force"           # Forces PCIe Active State Power Management
	    "nvme_core.default_ps_max_latency=0" # Fixes NVMe controller state transition drops
	    "amd_iommu=off"             # Prevents IOMMU page faults from interrupting s2idle transitions
    ];

# Environment Variables
    environment.sessionVariables = {
	#QT_QPA_PLATFORMTHEME = "hyprqt6engine";
	#QT_PLUGIN_PATH = "${hyprqt6engine}/lib/qt-6";
	NIXOS_OZONE_WL = "1";
    };

# Enable CUPS to print documents.
    services.printing.enable = true;

# Enable bluetooth
    hardware.bluetooth = {
	enable = true;
	powerOnBoot = false;
    };

# Enable sound.
# services.pulseaudio.enable = true;
# OR
    services.pipewire = {
	enable = true;
	pulse.enable = true;
	jack.enable = true;
	alsa.enable = true;
	wireplumber.enable = true;
    };

# Enable touchpad support (enabled default in most desktopManager).
# services.libinput.enable = true;

# Enable battery support
    services.upower.enable = true;
    services.power-profiles-daemon = {
	enable = true;	
    };

# Enable fingerprint support
    services.fprintd.enable = true;

# Define a user account. Don't forget to set a password with ‘passwd’.
    users.users.bonta = {
	isNormalUser = true;
	extraGroups = [ "wheel" "video" "input" ]; # Enable ‘sudo’ for the user.
    };

# Nix module programs
    programs.bash.enable = true;

    programs.hyprland = {
	enable = true;
	withUWSM = false;
	xwayland.enable = true;
    };
    programs.bash.loginShellInit = ''
	if [ "$(tty)" = "/dev/tty1" ]; then
	    exec start-hyprland
		fi
		'';

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
    system.stateVersion = "25.11"; # Did you read the comment?

}

