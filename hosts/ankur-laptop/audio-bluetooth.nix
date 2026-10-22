{ ... }: {
  # Your original PipeWire+ALSA+PulseAudio and Bluetooth configuration remains in
  # configuration.nix. Disable this entire module without changing that baseline.
  my.system.audioBluetooth = {
    enable = true;
    diagnostics.enable = true;

    bluetooth.blueman.enable = true;               # GUI replacement for Plasma Bluetooth
    bluetooth.applet.enable = true;                # Home Manager tray in Hyprland
    bluetooth.batteryReporting.enable = false;     # BlueZ experimental flag
    bluetooth.fastConnectable.enable = false;     # extra power consumption
    bluetooth.codecHints.enable = false;          # only tune if needed
    bluetooth.disableHeadsetAutoSwitch.enable = false;

    tools.easyeffects.enable = false;
    tools.helvum.enable = false;
    tools.qjackctl.enable = false;
    jack.enable = false;                          # do not change existing audio stack
  };
}
