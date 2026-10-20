{ lib, osConfig, ... }:

{
  config = lib.mkIf (osConfig.my.apps.desktop.enable && osConfig.my.apps.desktop.hyprlock.enable) {

  xdg.configFile."hypr/hyprlock.conf".source =
    ./hyprlock/hyprlock.conf;
};
}
