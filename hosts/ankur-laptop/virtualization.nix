{ ... }: {
  # Dormant by default: adding this file installs NOTHING from this module.
  # First set the master enable=true, then turn on only what you need.
  my.system.virtualization = {
    enable = false;
    podman.enable = false;
    distrobox.enable = false;
    qemuKvm.enable = false;
    virtManager.enable = false;
    virtViewer.enable = false;
  };

  # Docker already exists at my.apps.development.docker.enable = false;
  # in hosts/ankur-laptop/applications.nix. Keep using that single switch.
}
