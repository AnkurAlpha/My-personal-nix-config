{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.printingPeripherals;
  flag = description: lib.mkOption {
    type = lib.types.bool;
    default = false;
    inherit description;
  };
in
{
  options.my.system.printingPeripherals = {
    enable = lib.mkEnableOption "additional printing and peripheral features";

    printing = {
      cups.enable = flag "Enable CUPS if it is not already enabled elsewhere.";
      gui.enable = flag "Enable system-config-printer for printer administration.";
      discovery.enable = flag "Enable Avahi for local printer/device discovery.";
    };

    scanning = {
      sane.enable = flag "Enable SANE scanner support.";
      airscan.enable = flag "Enable the SANE AirScan network scanner backend.";
      gui.enable = flag "Install Simple Scan graphical scanning utility.";
    };

    mobile = {
      mtp.enable = flag "Install Android MTP transfer utilities.";
      adb.enable = flag "Enable the NixOS Android Debug Bridge integration.";
      ios.enable = flag "Install iOS device transfer/mounting tools.";
    };

    peripherals = {
      usbInspect.enable = flag "Install USB inspection utilities (usbutils).";
      thunderbolt.enable = flag "Enable the Bolt Thunderbolt device authorization service.";
    };
  };

  # mkIf ensures false flags contribute NO definitions. In particular, an
  # existing 'services.printing.enable = true;' is never turned off here.
  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf cfg.printing.cups.enable {
      services.printing.enable = true;
    })
    (lib.mkIf cfg.printing.gui.enable {
      services.system-config-printer.enable = true;
      environment.systemPackages = [ pkgs.system-config-printer ];
    })
    (lib.mkIf cfg.printing.discovery.enable {
      services.avahi.enable = true;
      # Intentionally do not modify firewall ports or advertise services.
    })
    (lib.mkIf cfg.scanning.sane.enable {
      hardware.sane.enable = true;
    })
    (lib.mkIf cfg.scanning.airscan.enable {
      hardware.sane.enable = true;
      hardware.sane.extraBackends = [ pkgs.sane-airscan ];
    })
    (lib.mkIf cfg.scanning.gui.enable {
      environment.systemPackages = [ pkgs.simple-scan ];
    })
    (lib.mkIf cfg.mobile.mtp.enable {
      environment.systemPackages = [ pkgs.android-file-transfer pkgs.libmtp ];
    })
    (lib.mkIf cfg.mobile.adb.enable {
      programs.adb.enable = true;
    })
    (lib.mkIf cfg.mobile.ios.enable {
      environment.systemPackages = [ pkgs.libimobiledevice pkgs.ifuse ];
    })
    (lib.mkIf cfg.peripherals.usbInspect.enable {
      environment.systemPackages = [ pkgs.usbutils ];
    })
    (lib.mkIf cfg.peripherals.thunderbolt.enable {
      services.hardware.bolt.enable = true;
    })
  ]);
}
