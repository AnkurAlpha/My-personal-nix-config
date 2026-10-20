{ lib, osConfig, ... }:

{
  config = lib.mkIf (osConfig.my.apps.desktop.enable && osConfig.my.apps.desktop.wofi.enable) {
  xdg.configFile."wofi/config".source =
    ./wofi/config;

  xdg.configFile."wofi/style.css".source =
    ./wofi/style.css;

  xdg.configFile."wofi/style.widgets.css".source =
    ./wofi/style.widgets.css;
};
}
