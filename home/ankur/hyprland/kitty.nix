{ lib, osConfig, ... }:

{
  config = lib.mkIf (osConfig.my.apps.desktop.enable && osConfig.my.apps.desktop.kitty.enable) {
  xdg.configFile."kitty/kitty.conf".text =
    if osConfig.my.apps.desktop.fish.enable then builtins.readFile ./kitty/kitty.conf
    else lib.replaceStrings [ "shell fish" ] [ "" ] (builtins.readFile ./kitty/kitty.conf);
};
}
