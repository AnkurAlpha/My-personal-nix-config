{ pkgs, ... }:

{
  xdg.configFile."hypr/hyprland.lua".source =
    ./hyprland.lua;

  home.packages = with pkgs; [
    kitty
    zellij
    waybar
    wofi
    mako
    networkmanagerapplet
    cliphist
    wl-clipboard
    brightnessctl
    pamixer
    libnotify
  ];
}
