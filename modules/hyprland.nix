{ lib, config, ... }:
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };
  # Core compositor retained independently of desktop applications.
  # KDE remains an alternative session if desktop tools are switched off.
  security.pam.services.hyprlock = lib.mkIf
    (config.my.apps.desktop.enable && config.my.apps.desktop.hyprlock.enable) {};
}
