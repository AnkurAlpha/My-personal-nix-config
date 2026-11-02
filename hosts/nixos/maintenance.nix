{ ... }: {
  # Native NixOS features, separate from the Home Manager application switches.
  # Each feature also requires the top-level maintenance.enable switch.
  my.system.maintenance = {
    enable = true;
    diagnostics.enable = true;         # nix-health (read-only)
    fstrim.enable = false;             # Optional: trim all eligible mounts; inspect first
    btrfsScrub.enable = false;         # Optional: ONLY NixOS Btrfs root (/)
    smartMonitoring.enable = false;    # Optional: SMART monitoring daemon
    firmwareService.enable = false;    # Optional: fwupd, without auto-updating
    storeOptimisation.enable = false;  # Optional: deduplicate Nix store
  };
}
