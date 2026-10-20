{ lib, pkgs, osConfig, ... }:

{
  config = lib.mkIf (osConfig.my.apps.desktop.enable && osConfig.my.apps.desktop.zellij.enable) {
  programs.zellij.enable = true;

  xdg.configFile."zellij" = {
    source = ./zellij;
    recursive = true;
  };
};
}
