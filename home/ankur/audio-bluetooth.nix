{ osConfig, ... }: {
  # Run exactly one Blueman tray service in the graphical session.
  # UWSM/Hyprland starts graphical-session.target for Home Manager user units.
  services.blueman-applet.enable =
    osConfig.my.system.audioBluetooth.enable
    && osConfig.my.system.audioBluetooth.bluetooth.blueman.enable
    && osConfig.my.system.audioBluetooth.bluetooth.applet.enable;
}
