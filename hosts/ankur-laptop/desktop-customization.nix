{ ... }:
{
  # Every switch is disabled. No new packages, daemons, theme overrides,
  # fonts, cursor or wallpaper choices are applied by installation.
  my.system.desktopCustomization = {
    enable = false;

    gtkThemeEditor.enable = false;
    qtThemeEditor.enable = false;
    iconThemes.enable = false;
    cursorThemes.enable = false;
    extraFonts.enable = false;
    fontManager.enable = false;
    colorPicker.enable = false;
    wallpaperGui.enable = false;
    nightLightTool.enable = false;
    screenshotAnnotator.enable = false;
    notificationCli.enable = false;
  };
}
