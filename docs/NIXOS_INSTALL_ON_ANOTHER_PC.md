# Installing this NixOS configuration on another PC

> **Important:** This repository is a working personal NixOS configuration, **not** a universal installer. The `scripts/reinstall-nixos/` scripts are designed for the original machine's `nvme0n1p6`/`p7` and shared Garuda/Windows boot arrangement. **Never run those scripts unchanged on another computer.**

This guide describes a fresh, **manual and reviewable** installation using a fork of [`AnkurAlpha/My-personal-nix-config`](https://github.com/AnkurAlpha/My-personal-nix-config). The example uses a UEFI computer and Btrfs with four subvolumes. It does **not** assume the original laptop's drive names, UUIDs, GPUs, username, or boot setup.

## 1. Back up and plan the target machine

1. Back up personal data, SSH/GPG keys, password-store files, browser profiles, and recovery keys to media **outside** the target disk. Test that you can restore important files.
2. Boot the NixOS graphical installer USB in **UEFI** mode. Connect to the internet.
3. Inspect the actual storage layout before making any changes:

   ```bash
   lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL,UUID,MOUNTPOINTS
   sudo parted -l
   test -d /sys/firmware/efi && echo 'UEFI boot confirmed'
   ```

4. Decide whether this is (A) a clean, dedicated NixOS machine or (B) a multi-boot machine. For multi-boot, identify the existing EFI System Partition (ESP), verify its available capacity, and **do not format it**. Windows recovery, OEM, and other operating system partitions must be preserved.
5. Create/resize partitions **manually**, only after backups and disk identification. For a new standalone UEFI installation, a typical plan includes an ESP (FAT32) and a Btrfs root partition. Partition sizes and device names are machine-specific. No automated destructive partitioning commands are provided in this repository.

## 2. Create and mount Btrfs subvolumes

The following commands are **templates**, not commands to run unchanged. Replace the variables after verifying their devices with `lsblk -f`. The Btrfs root must be a **new/empty** filesystem. Formatting erases everything on that partition.

```bash
# EXAMPLES ONLY: substitute the actual partitions on the NEW computer.
ROOT_DEV=/dev/REPLACE_WITH_NEW_BTRFS_ROOT
EFI_DEV=/dev/REPLACE_WITH_EXISTING_OR_NEW_ESP
lsblk -f "$ROOT_DEV" "$EFI_DEV"
```

Create a Btrfs filesystem on the root partition **only if you explicitly chose to erase that partition**. A standalone new ESP also needs FAT32 formatting, but **never format an existing shared ESP**. Use the installer/partition manager to create these filesystems after checking the exact targets.

After the new root has been formatted as Btrfs:

```bash
sudo mount "$ROOT_DEV" /mnt
for sv in @root @home @nix @log; do
  sudo btrfs subvolume create "/mnt/$sv"
done
sudo umount /mnt

sudo mount -o subvol=@root,compress=zstd:3,noatime "$ROOT_DEV" /mnt
sudo mkdir -p /mnt/home /mnt/nix /mnt/var/log /mnt/boot
sudo mount -o subvol=@home,compress=zstd:3,noatime "$ROOT_DEV" /mnt/home
sudo mount -o subvol=@nix,compress=zstd:3,noatime "$ROOT_DEV" /mnt/nix
sudo mount -o subvol=@log,compress=zstd:3,noatime "$ROOT_DEV" /mnt/var/log
sudo mount "$EFI_DEV" /mnt/boot
findmnt -R /mnt
```

Use `/boot` for the ESP **only if your selected bootloader configuration expects `/boot`**. On an existing multi-boot PC, carefully choose how NixOS will coexist with the other bootloader(s); do not copy this repository's Garuda-first firmware policy without reviewing the new computer's setup.

## 3. Generate new hardware information

```bash
sudo nixos-generate-config --root /mnt
```

The generated `/mnt/etc/nixos/hardware-configuration.nix` contains the **new computer's** filesystem UUIDs and hardware drivers. Keep the root/home/nix/log Btrfs mount definitions and the new ESP UUID, and review all mount options. For a FAT32 ESP mounted at `/boot`, use `fmask=0077,dmask=0077` to protect systemd-boot's random-seed file. **Never copy the original laptop's `hosts/nixos/hardware-configuration.nix` onto another machine.**

## 4. Fork the repository and create a new host

1. Fork the repository to an account you control. Work on a branch in your fork and clone it in the live environment. `git` can be supplied temporarily with `nix-shell -p git` or `nix shell nixpkgs#git`.
2. Copy the **host directory** `hosts/nixos/` to a new directory such as `hosts/newpc/`. Preserve or adjust relative module imports thoughtfully. Replace the copied `hardware-configuration.nix` with the newly generated file from step 3.
3. In the new host's `configuration.nix`, update `networking.hostName`, user account and groups, and the bootloader configuration. Remove `/mnt/garuda` and any other original-machine mounts unless they actually exist on this PC.
4. Review every imported module for laptop-specific values: GPU and NVIDIA PRIME IDs, video drivers, Wi-Fi and Bluetooth, kernel choice, virtualization, power/ACPI, secure boot, boot EFI policy, locale, sound, and application selections. Disable or replace incompatible modules before evaluating.
5. Update the flake so `nixosConfigurations.newpc` is exported **exactly once**, using the repository's existing `nixpkgs.lib.nixosSystem`, Home Manager integration and shared modules as a pattern. Don't simply rename the original output without checking its imports.
6. Update **all** Home Manager definitions, users, paths, and module defaults currently tied to `ankur` or `/home/ankur`. This repo is not automatically username-independent. Do not publish copied credentials.
7. Keep `system.stateVersion` appropriate to the **new** NixOS installation (usually the release used for the first install), rather than copying it blindly from an existing machine. Changing it later is not how upgrades are performed.
8. If using Btrfs on the new PC, enable monthly scrub **once per Btrfs filesystem**, usually with `fileSystems = [ "/" ];`. On an ext4-based host, do not import the Btrfs-specific module.

## 5. Evaluate and install the adapted flake

From the live environment, after editing the forked checkout and copying in the new hardware configuration:

```bash
REPO=/path/to/your/cloned/fork
HOST=newpc
cd "$REPO"
git add flake.nix hosts/"$HOST"   # ensures new files are visible to Git-backed flakes
nix eval --raw ".#nixosConfigurations.${HOST}.config.networking.hostName"
nix build --no-link ".#nixosConfigurations.${HOST}.config.system.build.toplevel"
sudo nixos-install --flake "$REPO#$HOST"
```

These are **not** guaranteed to work until the new host's imports, user, bootloader, Home Manager settings, and hardware definitions have been adapted. An evaluation/build failure should be fixed before installation, never worked around by deleting other OS partitions.

The installer typically prompts for a root password. Set the intended regular user's password in the installed system if necessary:

```bash
sudo nixos-enter --root /mnt -c 'passwd YOUR_NEW_USERNAME'
```

Do not declare plaintext passwords in the public repo, and do not put private SSH keys, GPG directories, `.password-store`, `/etc/shadow`, or cloud secrets into Git.

## 6. First boot and post-install checks

1. Keep the live USB available. Boot using the correct UEFI entry and confirm the NixOS system starts. Multi-boot GRUB entries are **not** automatically generated by this repository for arbitrary computers.
2. Log into a TTY first if the graphical login fails. Check `journalctl -b -u display-manager`; the original laptop's Elegant SDDM theme submitted a blank username, and `elarun` resolved that on that machine.
3. Put the adapted repo in your normal user's home directory, set ownership appropriately, and use `nh os test . -H newpc` before `nh os switch . -H newpc`.
4. Verify filesystem mounts and scrubbing:

   ```bash
   findmnt -R /
   systemctl list-timers --all | grep btrfs-scrub
   sudo btrfs scrub status /
   git status -sb
   ```

   A scrub that has **never run** may have no status yet; the timer should still be listed.
5. Verify the EFI file permissions as root (`sudo stat -c '%a %n' /boot/loader/random-seed`). FAT32's permission mask can present a secure root-only file mode as `700` rather than `600`.
6. Commit only reviewed, intended configuration changes. Push to your **fork**, not the original author's main branch. Maintain offline backups; Btrfs scrub and NixOS generations are not backups.

## References

- [Official NixOS installation manual](https://nixos.org/manual/nixos/stable/#sec-installation)
- [Official NixOS Wiki: Btrfs](https://wiki.nixos.org/wiki/Btrfs)
- [Btrfs scrub documentation](https://btrfs.readthedocs.io/en/latest/Scrub.html)
- [This repository's original-laptop reinstall procedure](NIXOS_BTRFS_REINSTALL.md)
