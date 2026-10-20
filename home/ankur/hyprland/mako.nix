{ lib, osConfig, ... }:

{
  config = lib.mkIf (osConfig.my.apps.desktop.enable && osConfig.my.apps.desktop.mako.enable) {
  xdg.configFile."mako/config".source =
    ./mako/config;
};
}
