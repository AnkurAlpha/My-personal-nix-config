{ lib, osConfig, ... }:

let
  c = osConfig.my.apps.desktop;
in
{
  xdg.configFile."nwg-drawer/drawer.css" =
    lib.mkIf (c.enable && c.drawer.enable) {
      source = ./drawer/drawer.css;
    };
}
