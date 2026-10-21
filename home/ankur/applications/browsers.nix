# Browsers are installed for ankur only, controlled by host switches.
# Browser profiles, bookmarks and other user data are not modified.
{ lib, pkgs, osConfig, ... }:
let
  browsers = osConfig.my.apps.browsers;
  selected = name: browsers.enable && browsers.${name}.enable;
in
{
  home.packages =
    (lib.optionals (selected "firefox") [ pkgs.firefox ])
    ++ (lib.optionals (selected "chromium") [ pkgs.chromium ])
    ++ (lib.optionals (selected "vivaldi") [ pkgs.vivaldi ]);
}
