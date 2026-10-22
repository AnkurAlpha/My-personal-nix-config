# Storage & Filesystems — disabled-by-default NixOS module

All new options are OFF in `hosts/ankur-laptop/storage-filesystems.nix`.
`my.system.storageFilesystems.enable = true` is additionally required to use any
individual switch. Importing this module does not change existing mounts or
services, install tools, format disks, create snapshots, or start automounting.

## Existing mounts are intentionally preserved

- `/` (ext4) and `/boot` (vfat) are declared in `hosts/ankur-laptop/hardware-configuration.nix`.
- `/mnt/garuda` (Btrfs, `subvolid=5`, `nofail`) is already declared in the host's `configuration.nix`.
- Neither file is modified here, other than adding imports to `configuration.nix`.
- Mounting Garuda, enabling Btrfs tools, and enabling scheduled Btrfs scrub are **different operations**. This module does not configure scheduled scrubs or write to Garuda.

## Switches

- `tools.ntfs.enable`: ntfs-3g userspace tools
- `tools.exfat.enable`: exfatprogs
- `tools.btrfs.enable`: btrfs-progs, no scrub or snapshot job
- `tools.fuse.enable`: fuse3 tools, no configured mounts
- `tools.sshfs.enable`: sshfs binary, no configured network mounts
- `tools.cifs.enable`: cifs-utils binary, no configured SMB mounts
- `tools.f2fs.enable`: f2fs-tools binary
- `tools.luks.enable`: cryptsetup binary, no auto-unlock
- `removable.udisks2.enable`: UDisks2 daemon
- `removable.gvfs.enable`: GVfs daemon integration
- `removable.udiskieAutomount.enable`: opt-in Home Manager Udiskie service and UDisks2

To enable a tool, edit `hosts/ankur-laptop/storage-filesystems.nix`, set
`enable = true;`, then set an individual option to true. For example:

```nix
my.system.storageFilesystems = {
  enable = true;
  tools.ntfs.enable = true;
  # Keep all other individual switches false.
};
```

Then run:

```sh
nh os build ~/nixos-config -H ankur-laptop
nh os switch ~/nixos-config -H ankur-laptop
```

If enabling Udiskie automount, ensure you want removable volumes mounted in
user sessions. It does not replace your existing declarative Garuda mount.
Do not independently activate competing automounters without checking them.

Reference mount `/mnt/garuda` was queried read-only during installation if
present. No contents were copied into the Git repository.
