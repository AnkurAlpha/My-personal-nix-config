{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.storageFilesystems;
  selected = feature: cfg.enable && feature.enable;
  inherit (lib) mkEnableOption mkIf optionals;
in
{
  # This module intentionally DOES NOT set fileSystems, swapDevices,
  # boot.supportedFilesystems, boot.initrd, or any /mnt/garuda mount options.
  # All feature declarations have default=false.
  options.my.system.storageFilesystems = {
    enable = mkEnableOption "optional filesystem management and removable-drive integrations";

    tools.ntfs.enable = mkEnableOption "ntfs-3g tools (no mounts configured)";
    tools.exfat.enable = mkEnableOption "exfatprogs (no mounts configured)";
    tools.btrfs.enable = mkEnableOption "btrfs-progs (no Btrfs tasks configured)";
    tools.fuse.enable = mkEnableOption "FUSE3 utilities (no filesystems mounted)";
    tools.sshfs.enable = mkEnableOption "SSHFS command-line utility (no network mounts)";
    tools.cifs.enable = mkEnableOption "CIFS/SMB mounting utilities (no network mounts)";
    tools.f2fs.enable = mkEnableOption "F2FS filesystem utilities";
    tools.luks.enable = mkEnableOption "cryptsetup command-line utility (no unlocking)";

    removable.udisks2.enable = mkEnableOption "UDisks2 removable-drive management service";
    removable.gvfs.enable = mkEnableOption "GVfs virtual filesystem integration";
    removable.udiskieAutomount.enable = mkEnableOption "Udiskie user automounter (requires UDisks2)";
  };

  config = {
    environment.systemPackages =
      (optionals (selected cfg.tools.ntfs) [ pkgs.ntfs3g ])
      ++ (optionals (selected cfg.tools.exfat) [ pkgs.exfatprogs ])
      ++ (optionals (selected cfg.tools.btrfs) [ pkgs.btrfs-progs ])
      ++ (optionals (selected cfg.tools.fuse) [ pkgs.fuse3 ])
      ++ (optionals (selected cfg.tools.sshfs) [ pkgs.sshfs ])
      ++ (optionals (selected cfg.tools.cifs) [ pkgs.cifs-utils ])
      ++ (optionals (selected cfg.tools.f2fs) [ pkgs.f2fs-tools ])
      ++ (optionals (selected cfg.tools.luks) [ pkgs.cryptsetup ]);

    # Udiskie requires UDisks2 to be available; both are OFF initially.
    services.udisks2.enable = mkIf (cfg.enable && (cfg.removable.udisks2.enable || cfg.removable.udiskieAutomount.enable)) true;
    services.gvfs.enable = mkIf (selected cfg.removable.gvfs) true;
  };
}
