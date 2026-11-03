{ lib, config, ... }:
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };
  # Core compositor retained independently of desktop applications.
  # Plasma availability is controlled separately by the host KDE cleanup policy.
  security.pam.services.hyprlock = lib.mkIf
    (config.my.apps.desktop.enable && config.my.apps.desktop.hyprlock.enable) {};
}
