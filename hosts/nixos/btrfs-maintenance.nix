{ ... }:
{
  # Run once for the whole NIXOS-BTRFS filesystem, not once per subvolume.
  # Explicitly excludes the separate Garuda Btrfs filesystem at /mnt/garuda.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };
}
