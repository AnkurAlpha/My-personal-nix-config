{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.virtualization;
in
{
  # No packages, services or group memberships are enabled merely by
  # importing this module. Every feature must be explicitly opted into.
  options.my.system.virtualization = {
    enable = lib.mkEnableOption "optional virtualization and container tools";
    podman.enable = lib.mkEnableOption "Podman container engine";
    distrobox.enable = lib.mkEnableOption "Distrobox containers on Podman or Docker";
    qemuKvm.enable = lib.mkEnableOption "QEMU/KVM through libvirtd";
    virtManager.enable = lib.mkEnableOption "Virt-Manager graphical interface";
    virtViewer.enable = lib.mkEnableOption "Virt-Viewer VM console client";
  };

  # Keep the pre-existing Docker switch at
  # my.apps.development.docker.enable; never define Docker twice.
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.distrobox.enable ||
            config.virtualisation.podman.enable ||
            config.virtualisation.docker.enable;
          message = "Distrobox needs a container engine: enable Podman here or the existing Docker switch.";
        }
      ];
    }
    (lib.mkIf cfg.podman.enable {
      virtualisation.podman.enable = true;
    })
    (lib.mkIf cfg.distrobox.enable {
      environment.systemPackages = [ pkgs.distrobox ];
    })
    (lib.mkIf cfg.qemuKvm.enable {
      virtualisation.libvirtd.enable = true;
      users.users.ankur.extraGroups = [ "libvirtd" ];
    })
    (lib.mkIf cfg.virtManager.enable {
      programs.virt-manager.enable = true;
    })
    (lib.mkIf cfg.virtViewer.enable {
      environment.systemPackages = [ pkgs.virt-viewer ];
    })
  ]);
}
