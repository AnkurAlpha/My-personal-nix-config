{ pkgs, ... }:

{
  imports = [
    ./kitty.nix
    ./wofi.nix
    ./mako.nix
    ./hyprlock.nix
    ./hypridle.nix
  ];
  xdg.configFile."hypr/hyprland.lua".source =
    ./hyprland.lua;

  home.packages = with pkgs; [
    kitty
    zellij
    waybar
    wofi
    wpaperd
    mako
    networkmanagerapplet
    grimblast
    cliphist
    wl-clipboard
    brightnessctl
    pamixer
    libnotify
    htop
    curl
    alsa-utils
    pavucontrol
    nwg-bar
    nwg-drawer
    nwg-dock-hyprland
    jq
    hyprpicker
    libnotify
  ];

  xdg.configFile."waybar" = {
  source = ./waybar;
  recursive = true;
};
xdg.configFile."wpaperd/config.toml".source =
  ./wpaperd/config.toml;

  xdg.configFile."nwg-dock-hyprland/style.css".source =
  ./dock/style.css;
}
