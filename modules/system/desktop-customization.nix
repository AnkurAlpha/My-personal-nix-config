{ lib, ... }:
{
  # Declaration only: importing this file adds NO desktop package or service.
  options.my.system.desktopCustomization = {
    enable = lib.mkEnableOption "optional Hyprland desktop customization tools";

    gtkThemeEditor.enable = lib.mkEnableOption "nwg-look GTK theme editor";
    qtThemeEditor.enable = lib.mkEnableOption "qt6ct Qt appearance editor (no Qt environment override)";
    iconThemes.enable = lib.mkEnableOption "Papirus icon theme (not applied automatically)";
    cursorThemes.enable = lib.mkEnableOption "Bibata cursor themes (not selected automatically)";
    extraFonts.enable = lib.mkEnableOption "Inter font family (without changing defaults)";
    fontManager.enable = lib.mkEnableOption "font-manager GUI";
    colorPicker.enable = lib.mkEnableOption "hyprpicker Wayland color picker";
    wallpaperGui.enable = lib.mkEnableOption "Waypaper wallpaper selector";
    nightLightTool.enable = lib.mkEnableOption "hyprsunset night light utility (manual only)";
    screenshotAnnotator.enable = lib.mkEnableOption "swappy screenshot annotator";
    notificationCli.enable = lib.mkEnableOption "libnotify notify-send CLI";
  };
}
