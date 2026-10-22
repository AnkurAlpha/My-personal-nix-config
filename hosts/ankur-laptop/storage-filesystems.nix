{ ... }:
{
  # All new functionality is disabled, including the master switch.
  # Existing /mnt/garuda, /, /boot mounts and existing services stay untouched.
  my.system.storageFilesystems = {
    enable = false;

    tools.ntfs.enable = false;
    tools.exfat.enable = false;
    tools.btrfs.enable = false;
    tools.fuse.enable = false;
    tools.sshfs.enable = false;
    tools.cifs.enable = false;
    tools.f2fs.enable = false;
    tools.luks.enable = false;

    removable.udisks2.enable = false;
    removable.gvfs.enable = false;
    removable.udiskieAutomount.enable = false;
  };
}
