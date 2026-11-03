# Reinstalling this NixOS host on Btrfs

**Scope: personal, hardware-specific configuration, not a universal installer.**

This repository includes the existing `nixos` host (`ankur`) and scripts under
`scripts/reinstall-nixos/` for **one verified dual/triple-boot disk layout**.
Do not run those scripts unchanged on another disk or computer.

## Original machine layout (historical runtime report)

- `/dev/nvme0n1p1`: shared Garuda/Windows EFI system partition — preserve
- `/dev/nvme0n1p2`, `p3`, and `p4`: Windows / recovery — preserve
- `/dev/nvme0n1p5`: Garuda Btrfs — preserve
- `/dev/nvme0n1p6`: 2 GiB FAT32 `NIXBOOT`, mounted at `/boot`
- `/dev/nvme0n1p7`: 200 GiB Btrfs `NIXOS-BTRFS`
- NixOS Btrfs subvolumes: `@root`, `@home`, `@nix`, `@log`
- Primary firmware boot order points to Garuda GRUB; GRUB chainloads
  `/EFI/systemd/systemd-bootx64.efi` from `NIXBOOT`.

Back up personal data before partitioning. Perform all partition moves/resizes
**manually and only after verifying** the disk identity, partition labels,
filesystem health, and a restorable backup. The included NixOS installer
scripts must never resize or format disks automatically.

## Historical repairs and current source notes

1. The `flake.nix` output `nixosConfigurations.nixos` must appear exactly once.
   An older temporary `nixos = ankurLaptop;` alias previously caused a
   duplicate-attribute evaluation failure.
2. `03_bootstrap_nixos_live.sh` checks Btrfs filesystem mount sources and
   subvolumes, **not** block-device `MAJ:MIN` values, which can differ on Btrfs.
3. The same bootstrap script uses `findmnt -R /mnt` for the preflight.
4. Freshly generated host hardware configuration is copied into
   `hosts/nixos/hardware-configuration.nix` and FAT32 `/boot` masks are
   hardened to `fmask=0077,dmask=0077` for systemd-boot's random seed.
5. Historical reinstall notes reported `elarun` as a working recovery greeter
   after `Elegant` submitted an empty username. The current source instead forces
   `sddm-astronaut-theme` with the `black_hole` theme package; verify current
   runtime separately. The older Elegant module remains imported.
6. Home Manager is integrated with NixOS: a system rebuild handles it.
7. Account passwords are set locally with `passwd`, not in the public flake.

## Routine validation on this machine

```bash
cd ~/nixos-config
nix eval --raw .#nixosConfigurations.nixos.config.networking.hostName
nix eval --raw .#nixosConfigurations.nixos.config.services.displayManager.sddm.theme
nix eval --json .#nixosConfigurations.nixos.config.boot.loader.efi.canTouchEfiVariables
nix build --no-link .#nixosConfigurations.nixos.config.system.build.toplevel
```

Apply an intentional, tested config update with `nh os switch . -H nixos`.

## If you fork this repository

**Do not run the included reinstall scripts unchanged.** You must replace
machine-specific hardware settings, UUIDs, disks, filesystem mounts, username,
home directory paths, bootloader/EFI policy, GPU drivers, host name and
`system.stateVersion` (which should remain appropriate for your own install).
Generate a new `hardware-configuration.nix` on your own target system, and
inspect all imported modules before building. On other layouts, use the
standard NixOS install guide rather than the hard-coded migration scripts.

Never publish passwords, `/etc/shadow`, private SSH/GPG keys, cloud credentials,
`.env` files, or recovery data. Disk UUIDs are not credentials but do identify
this machine's storage configuration.
