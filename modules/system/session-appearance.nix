{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.sessionAppearance;
  sweetGreeter = pkgs.elegant-sddm.override {
    themeConfig.General.background = "${../../assets/sddm-sweet-background.png}";
  };
  sweetCursor = pkgs.runCommand "sweet-sddm-cursor" {} ''
    mkdir -p "$out/share/icons"
    cp -r ${../../home/ankur/themes/Sweet-cursors} "$out/share/icons/Sweet-cursors"
  '';
in
{
  options.my.system.sessionAppearance = {
    enable = lib.mkEnableOption "optional Hyprland night-light and SDDM theming";
    hyprsunset.enable = lib.mkEnableOption "all-day scheduled warm colors in Hyprland";
    loginTheme.enable = lib.mkEnableOption "Sweet-inspired Elegant Qt6 SDDM login greeter";
  };

  config = lib.mkIf (cfg.enable && cfg.loginTheme.enable) {
    # Keep SDDM, keep UWSM and Hyprland, do not enable KDE or KWallet.
    services.displayManager.sddm = {
      theme = "Elegant";
      extraPackages = [ sweetGreeter pkgs.kdePackages.qt5compat ];
      settings.Theme = {
        CursorTheme = "Sweet-cursors";
        CursorSize = 24;
      };
    };
    environment.systemPackages = [ sweetGreeter sweetCursor ];
  };
}
