# Maintenance and recovery scope

The original laptop uses Btrfs subvolumes `@root`, `@home`, `@nix`, `@log` on one
filesystem and a separate FAT32 `/boot`. `/mnt/garuda` is a different Btrfs
filesystem mounted at its top level with `nofail`. Original UUIDs remain only in
the original host; additional hosts generate their own hardware configuration.

Monthly scrub is enabled in `hosts/nixos/btrfs-maintenance.nix` for `/`. Do not add
one scrub per subvolume of the same filesystem. The generic maintenance module's
optional scrub flag is off, but that does not disable the direct host setting.
Scrub validates checksums; without a healthy redundant copy it may detect rather
than repair corruption. It does not create snapshots or backups.

```bash
findmnt -R / -o TARGET,SOURCE,FSTYPE,OPTIONS
systemctl list-timers --all | rg 'btrfs|fstrim'
sudo btrfs scrub status /
sudo btrfs device stats /
sudo btrfs filesystem usage -T /
journalctl -b -p warning --no-pager
nix-health
```

A scrub that has never run can have no status yet. Inspect timers separately.
Manually starting a scrub creates I/O load; it is an intentional maintenance
operation, not part of a read-only audit. Avoid automatic defragmentation or
whole-filesystem balance commands without a concrete need and space/backup review.

Periodic fstrim is enabled by Garuda goodies. Its native service can operate on
other eligible mounted filesystems too; inspect `systemctl cat fstrim.service`.
Btrfs compression settings apply to writes; they are not a request to rewrite all
old data. NVMe scheduler settings apply during device setup. See the
[Garuda guide](GARUDA_GOODIES_ON_NIXOS.md) for exact owners and limitations.

ZRAM is 90% logical capacity with Zstandard; monitor `zramctl`, `swapon --show`,
`free -h` and `sysctl vm.swappiness`. A larger logical swap device does not create
more physical RAM. Optional earlyoom is off and asserts against competing oomd
when enabled. Do not add memory-killing services just because the module offers one.

`nix-update-safe` is a **manual** update helper, not an automatic timer. It builds
before switching and can commit after success. The current host protects
FIMLoom, SmoothCursor and Nixpkgs' explicit pin. Store optimisation, fwupd and SMART
monitoring are separate optional features and currently disabled in the generic
maintenance selection. Garbage collection is not automatically enabled by that
module or by the universal installer.

One existing automation does delete user data: `home/ankur/trash-cleanup.nix`
runs `trash-empty 30` daily. This permanently removes trash entries older than
30 days, including after missed runs because the timer is persistent. It was
preserved. Inspect with `systemctl --user cat trash-cleanup` and
`systemctl --user list-timers --all`. Remove that import deliberately if you no
longer want this policy; it is separate from Nix store cleanup.

Keep off-device backups of projects, home data, SSH/GPG keys, secrets, databases,
licensed assets and any EFI boot files needed for multi-boot recovery. A Git
checkout backs up only committed configuration. For generation retention,
rollback and cautious cleanup commands see [Commands](COMMANDS.md). For the old
laptop's disk-specific reinstall tools see
[Btrfs reinstall](NIXOS_BTRFS_REINSTALL.md); they are never the portable default.
