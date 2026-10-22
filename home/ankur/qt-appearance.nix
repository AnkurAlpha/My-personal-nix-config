{ config, lib, osConfig, ... }:
let
  c = osConfig.my.system.qtAppearance;
  # Reuse the same appearance controls as the existing GTK theme, so switching
  # the existing appearance module off also switches this complement off.
  gtkThemeActive = osConfig.my.apps.appearance.enable && osConfig.my.apps.appearance.theme.enable;
  useQt = c.enable && gtkThemeActive;
  useKvantum = c.kvantum.enable;
  appearance = {
    Appearance = {
      style = if useKvantum then "kvantum" else "Fusion";
      icon_theme = "BeautyLine";
      standard_dialogs = "xdgdesktopportal";
    };
  };
in
{
  config = lib.mkIf useQt {
    # Theme files from Garuda, stored declaratively in this repository.
    xdg.configFile."Kvantum/Sweet".source = ./themes/garuda-exact-kvantum/Sweet;
    qt = {
      enable = true;
      # Home Manager installs qt5ct and qt6ct and exports the appropriate
      # QT_QPA_PLATFORMTHEME into user sessions (including systemd apps).
      platformTheme.name = "qtct";
      style.name = if useKvantum then "kvantum" else null;
      qt5ctSettings = if c.qt5Settings.enable then appearance else null;
      qt6ctSettings = if c.qt6Settings.enable then appearance else null;
      kvantum = {
        enable = useKvantum;
        # KvDark ships with the Kvantum engine; avoid KDE/Plasma integration.
        # Disable compositing in Kvantum to avoid a known Qt6/Wayland issue.
        settings.General = {
          theme = "Sweet";
          composite = false;
        };
      };
    };
  };
}
