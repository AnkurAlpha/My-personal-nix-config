{ lib, pkgs, osConfig, ... }:
let
  c = osConfig.my.apps.systemTools;
  add = on: package: lib.optional (c.enable && on) package;
in {
  # Per-app switches are configured in hosts/ankur-laptop/applications.nix.
  # This module does not enable services, automatic garbage collection,
  # firmware changes, partition operations, or privileged monitoring.
  home.packages =
      add c.btop.enable pkgs.btop
    ++ add c.nvtop.enable pkgs.nvtopPackages.nvidia
    ++ add c.iotop.enable pkgs.iotop
    ++ add c.powertop.enable pkgs.powertop
    ++ add c.gdu.enable pkgs.gdu
    ++ add c.duf.enable pkgs.duf
    ++ add c.dust.enable pkgs.dust
    ++ add c.ncdu.enable pkgs.ncdu
    ++ add c.filelight.enable pkgs.kdePackages.filelight
    ++ add c.gnomeDisks.enable pkgs.gnome-disk-utility
    ++ add c.smartmontools.enable pkgs.smartmontools
    ++ add c.lmSensors.enable pkgs.lm_sensors
    ++ add c.lshw.enable pkgs.lshw
    ++ add c.pciutils.enable pkgs.pciutils
    ++ add c.usbutils.enable pkgs.usbutils
    ++ add c.lsof.enable pkgs.lsof
    ++ add c.nixTree.enable pkgs.nix-tree
    ++ add c.nvd.enable pkgs.nvd
    ++ add c.nixOutputMonitor.enable pkgs.nix-output-monitor;
}
