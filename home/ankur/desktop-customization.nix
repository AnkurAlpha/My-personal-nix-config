{ config, lib, pkgs, osConfig, ... }:
let
  cfg = osConfig.my.system.desktopCustomization;
  inherit (lib) optionals;
in
{
  # Add packages only when master and individual switches are both enabled.
  # The existing home/ankur/theme.nix, fonts.nix and hyprland/* own the actual
  # GTK theme, pointer, fonts, Waybar, Mako, wallpaper and compositor config.
  config = lib.mkIf cfg.enable {
    home.packages =
      (optionals cfg.gtkThemeEditor.enable [ pkgs.nwg-look ])
      ++ (optionals cfg.qtThemeEditor.enable [ pkgs.qt6ct ])
      ++ (optionals cfg.iconThemes.enable [ pkgs.papirus-icon-theme ])
      ++ (optionals cfg.cursorThemes.enable [ pkgs.bibata-cursors ])
      ++ (optionals cfg.extraFonts.enable [ pkgs.inter ])
      ++ (optionals cfg.fontManager.enable [ pkgs.font-manager ])
      ++ (optionals cfg.colorPicker.enable [ pkgs.hyprpicker ])
      ++ (optionals cfg.wallpaperGui.enable [ pkgs.waypaper ])
      ++ (optionals cfg.nightLightTool.enable [ pkgs.hyprsunset ])
      ++ (optionals cfg.screenshotAnnotator.enable [ pkgs.swappy ])
      ++ (optionals cfg.notificationCli.enable [ pkgs.libnotify ]);
  };
}
