{ ... }:
{
  # Qt was missing; enable it to complement existing Sweet-Dark GTK settings.
  my.system.qtAppearance = {
    enable = true;
    qt5Settings.enable = true;
    qt6Settings.enable = true;
    kvantum.enable = true;
  };
}
