{ lib, osConfig, ... }:

{
  config = lib.mkIf (osConfig.my.apps.desktop.enable && osConfig.my.apps.desktop.hypridle.enable) {

  xdg.configFile."hypr/hypridle.conf".source =
    ./hypridle/hypridle.conf;
};
}
