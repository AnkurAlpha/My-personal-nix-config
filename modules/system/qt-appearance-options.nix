{ lib, ... }:
{
  # Individual opt-in switches; the GTK Sweet-Dark theme is managed elsewhere.
  options.my.system.qtAppearance = {
    enable = lib.mkEnableOption "declarative Qt theme matching the existing dark GTK appearance";
    qt5Settings.enable = lib.mkEnableOption "manage qt5ct appearance and BeautyLine icons";
    qt6Settings.enable = lib.mkEnableOption "manage qt6ct appearance and BeautyLine icons";
    kvantum.enable = lib.mkEnableOption "use Kvantum dark widgets for Qt5 and Qt6";
  };
}
