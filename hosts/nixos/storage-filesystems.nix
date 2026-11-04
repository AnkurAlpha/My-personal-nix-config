{ ... }:
{
  # User-session automounting for removable media; existing declared mounts stay fixed.
  my.system.storageFilesystems = {
    enable = true;

    tools.ntfs.enable = true;
    tools.exfat.enable = true;
    tools.usbutils.enable = true;
    tools.btrfs.enable = false;
    tools.fuse.enable = false;
    tools.sshfs.enable = false;
    tools.cifs.enable = false;
    tools.f2fs.enable = false;
    tools.luks.enable = false;

    removable.udisks2.enable = true;
    removable.gvfs.enable = true;
    removable.udiskieAutomount.enable = true;
  };
}
