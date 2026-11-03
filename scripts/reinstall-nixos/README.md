# Reinstall the existing NixOS flake on Btrfs, host `nixos`

**For this one laptop only:** disk `/dev/nvme0n1`, Garuda `p5`, Nix boot `p6`, NixOS root `p7`. Do not run these scripts on another machine.

The scripts intentionally **never resize, move, partition, format, or erase a disk**. Partition operations must happen after a separate, verified backup and capacity audit. The commands below use GNU Bash even when your Garuda login shell is Fish.

## On Garuda, BEFORE repartitioning

1. Verify the current Git checkout is clean and synchronized; do not rely on a historical commit hash.
2. Back up any personal data on old NixOS `p7` that is not tracked in GitHub (projects, GPG/SSH keys, secrets, databases, etc.). Copy anything irreplaceable off the SSD. GitHub only covers committed configuration, not personal state.
3. Check the Garuda Btrfs filesystem's **used space**:

   ```bash
   df -h /
   sudo btrfs filesystem usage -T /
   lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTUUID,MOUNTPOINTS /dev/nvme0n1
   ```

   You need room to shrink Garuda by about 102 GiB for a 200 GiB NixOS partition, or 52 GiB for a 150 GiB partition. Ensure large safety headroom.
4. The host/output is already named `nixos`. The historical `01_prepare_nixos_hostname.sh` helper is not shipped or needed.
5. Review and synchronize the actual current configuration before reinstalling. Confirm your expected commit exists on the remote; do not perform a hostname migration from an absent helper.

## Partition operation (GParted Live, manual and backup verified)

Actual order: `p5` Garuda 635.4 GiB Btrfs → `p6` NIXBOOT 2 GiB FAT32 → `p7` NixOS 98 GiB ext4.

For **200 GiB** NixOS, only if Garuda has sufficiently little used space:

- Boot a live environment and verify the SSD by model/partition labels. Unmount relevant partitions.
- Shrink **the right-hand edge** of Garuda `p5` by about 102 GiB; do not touch the left edge or EFI/Windows `p1-p4`.
- Move the existing `p6` 2 GiB NIXBOOT partition left into the newly freed gap, without formatting it. Move operations are risky and can invalidate firmware entries: keep a bootable rescue USB ready.
- Delete only the old `p7` *after backup*. Recreate NixOS `p7` using the now adjacent free space, sized **200 GiB** (or 150 GiB), filesystem **Btrfs**, label exactly `NIXOS-BTRFS`.
- Do not format p6, p5, p1, p2, p3, or p4. If GPT numbering or labels change, STOP; the scripts require p6/p7 at verified paths.

**No automated partition-erasing script is included.** Confirm Garuda and Windows are still accessible before proceeding. GParted manual: https://gparted.org/display-doc.php?name=moving-space-between-partitions

For any other computer, use the [universal installer](../../docs/INSTALLATION.md).

## From NixOS live USB (after GParted and valid network)

Clone the repo with one command; the live installer can obtain Git temporarily without permanently installing it:

```bash
nix-shell -p git --run 'git clone https://github.com/AnkurAlpha/My-personal-nix-config.git /tmp/nixos-config'
```

Then simply:

```bash
sudo bash /tmp/nixos-config/scripts/reinstall-nixos/02_mount_nixos_btrfs.sh
sudo bash /tmp/nixos-config/scripts/reinstall-nixos/03_bootstrap_nixos_live.sh
```

The mount script creates **only** `@root`, `@home`, `@nix`, `@log` on a confirmed empty Btrfs p7 named `NIXOS-BTRFS`; it mounts existing p6 at `/mnt/boot`. It never creates `@snapshots`.

The install script:

- Checks mounts belong to p7/p6 and refuses to operate on Garuda.
- Clones the latest GitHub flake into `/mnt/home/ankur/nixos-config`.
- Regenerates Btrfs hardware/filesystem configuration and replaces the tracked host hardware file, when the expected import path is present.
- Checks flake hostname `nixos`, systemd-boot on `/boot`, no UEFI variable modifications, and that Home Manager is integrated for `ankur`.
- Uses `nixos-install --flake ...#nixos`, then prompts to set an `ankur` login password.

**The scripts cannot prove ahead of time that the pinned flake compiles on the new hardware layout.** If a preflight fails, inspect the error rather than forcing a destructive workaround. Leave the USB available until all three OSes boot.

## After NixOS boots

- `hostname` should print `nixos`.
- The working flake is in `~/nixos-config`; the new hardware config may be locally modified. Review and commit it, then `git push` after confirming no secrets were included.
- Garuda GRUB remains the first UEFI entry. After `nixos-install` completes, reboot into **Garuda** (already first in UEFI order) and run:
  ```bash
  sudo bash ~/Downloads/04_garuda_grub_nixos_entry.sh
  ```
  The script backs up `/etc/grub.d/40_custom`, adds a chainload entry for p6's systemd-boot (no EFI boot order changes), and regenerates GRUB. Confirm the Windows entry remains present. It refuses to run if the expected GRUB/p6 files are absent.
- `@snapshots` is optional. Nix generations provide OS configuration rollback; Btrfs snapshots are useful for mutable files, not required for declarative packages. **Neither is a physical backup.**
