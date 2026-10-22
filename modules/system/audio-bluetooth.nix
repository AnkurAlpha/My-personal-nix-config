{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.audioBluetooth;
  audioBtHealth = pkgs.writeShellScriptBin "audio-bt-health" ''
    echo '=== Audio and Bluetooth (read-only) ==='
    echo 'PipeWire and policy services:'
    ${pkgs.systemd}/bin/systemctl --user is-active pipewire.service pipewire-pulse.service wireplumber.service || true
    echo
    echo 'Bluetooth system service:'
    ${pkgs.systemd}/bin/systemctl is-active bluetooth.service || true
    echo
    echo 'PipeWire default devices and streams:'
    ${pkgs.wireplumber}/bin/wpctl status || true
    echo
    echo 'Bluetooth controllers:'
    ${pkgs.bluez}/bin/bluetoothctl list || true
    echo
    echo 'No settings were modified.'
  '';
in
{
  options.my.system.audioBluetooth = {
    enable = lib.mkEnableOption "modular audio and Bluetooth additions";
    diagnostics.enable = lib.mkEnableOption "read-only audio-bt-health command";
    bluetooth = {
      blueman.enable = lib.mkEnableOption "Blueman Bluetooth GUI and service";
      applet.enable = lib.mkEnableOption "Blueman graphical-session tray applet (Home Manager)";
      batteryReporting.enable = lib.mkEnableOption "BlueZ experimental battery reporting support";
      fastConnectable.enable = lib.mkEnableOption "BlueZ fast-connectable mode (higher idle power draw)";
      codecHints.enable = lib.mkEnableOption "explicitly enable SBC-XQ and mSBC capabilities in WirePlumber";
      disableHeadsetAutoSwitch.enable = lib.mkEnableOption "prevent automatic music-to-call audio profile switching";
    };
    tools = {
      easyeffects.enable = lib.mkEnableOption "EasyEffects effects processor";
      helvum.enable = lib.mkEnableOption "Helvum PipeWire graph/patchbay";
      qjackctl.enable = lib.mkEnableOption "QjackCtl audio routing GUI";
    };
    jack.enable = lib.mkEnableOption "PipeWire JACK compatibility layer";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = config.services.pipewire.enable && config.services.pipewire.pulse.enable;
          message = "Audio/Bluetooth module expects the pre-existing PipeWire+PulseAudio compatibility setup.";
        }
        {
          assertion = config.hardware.bluetooth.enable;
          message = "Audio/Bluetooth module requires the pre-existing BlueZ Bluetooth setting.";
        }
        {
          assertion = !cfg.bluetooth.applet.enable || cfg.bluetooth.blueman.enable;
          message = "The Blueman tray applet requires bluetooth.blueman.enable = true.";
        }
      ];
      # Keep existing PipeWire, rtkit, PulseAudio, BlueZ and powerOnBoot declarations untouched.
      environment.systemPackages =
        lib.optional cfg.diagnostics.enable audioBtHealth
        ++ lib.optional cfg.tools.easyeffects.enable pkgs.easyeffects
        ++ lib.optional cfg.tools.helvum.enable pkgs.helvum
        ++ lib.optional cfg.tools.qjackctl.enable pkgs.qjackctl;
    }
    (lib.mkIf cfg.bluetooth.blueman.enable {
      services.blueman.enable = true;
    })
    (lib.mkIf cfg.bluetooth.batteryReporting.enable {
      hardware.bluetooth.settings.General.Experimental = true;
    })
    (lib.mkIf cfg.bluetooth.fastConnectable.enable {
      hardware.bluetooth.settings.General.FastConnectable = true;
    })
    (lib.mkIf cfg.bluetooth.codecHints.enable {
      services.pipewire.wireplumber.extraConfig."92-audio-bt-codecs" = {
        "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;
          "bluez5.enable-msbc" = true;
        };
      };
    })
    (lib.mkIf cfg.bluetooth.disableHeadsetAutoSwitch.enable {
      services.pipewire.wireplumber.extraConfig."93-audio-bt-headset-policy" = {
        "wireplumber.settings" = {
          "bluetooth.autoswitch-to-headset-profile" = false;
        };
      };
    })
    (lib.mkIf cfg.jack.enable {
      services.pipewire.jack.enable = true;
    })
  ]);
}
