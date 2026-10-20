{ lib, pkgs, osConfig, ... }:

{
  config = lib.mkIf (osConfig.my.apps.appearance.enable && osConfig.my.apps.appearance.fonts.enable) {
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    ubuntu-classic
    noto-fonts-color-emoji
  ];
};
}
