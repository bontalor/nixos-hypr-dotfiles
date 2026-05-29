{ config, pkgs, inputs, ... }:

{
  home.username = "bonta";
  home.homeDirectory = "/home/bonta";
  home.stateVersion = "25.11";

  # X11
  xresources.properties = {
    "Xft.dpi" = 144;
  };

  # Cursor
  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    x11.defaultCursor = "Adwaita";
  };

  # Programs
  home.packages = with pkgs; [
    tree
    fastfetch
    chatterino2
    discord
    spotify
    python3
    qmk_hid
    wmenu
    lua-language-server
  ];
  programs.bash = {
    enable = true;
  };
  programs.firefox = {
    enable = true;
    configPath = "${config.xdg.configHome}/mozilla/firefox";
  };
}
