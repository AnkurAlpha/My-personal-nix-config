#!/usr/bin/env bash
# Run from the NixOS live USB AFTER manually recreating p7 as Btrfs labelled NIXOS-BTRFS.
# Never formats, resizes, moves, or deletes partitions.
set -Eeuo pipefail
ROOT=/dev/nvme0n1p7
BOOT=/dev/nvme0n1p6
[[ "$(id -u)" == 0 ]] || { echo 'Run with sudo from the NixOS live USB' >&2; exit 1; }
for c in blkid mount findmnt lsblk btrfs mountpoint; do command -v "$c" >/dev/null || { echo "Missing $c" >&2; exit 1; }; done
[[ "$(blkid -s TYPE -o value "$ROOT")" == btrfs ]] || { echo 'p7 is not Btrfs. Format it manually in GParted first.' >&2; exit 1; }
[[ "$(lsblk -bn -o SIZE "$ROOT" | tr -d '[:space:]')" -ge $((145 * 1024 * 1024 * 1024)) ]] || { echo 'p7 is below 145 GiB. Resize to 150 or 200 GiB before proceeding.' >&2; exit 1; }
[[ "$(blkid -s LABEL -o value "$ROOT")" == NIXOS-BTRFS ]] || { echo 'p7 must have the new explicit label NIXOS-BTRFS; refusing to alter unknown Btrfs volume.' >&2; exit 1; }
[[ "$(blkid -s TYPE -o value "$BOOT")" == vfat && "$(blkid -s LABEL -o value "$BOOT")" == NIXBOOT ]] || { echo 'p6 is not the expected NIXBOOT FAT32 filesystem.' >&2; exit 1; }
[[ "$(lsblk -dn -o PKNAME "$ROOT")" == "$(lsblk -dn -o PKNAME "$BOOT")" ]] || { echo 'p6 and p7 on unexpected different disks' >&2; exit 1; }
for path in /mnt /mnt/home /mnt/nix /mnt/var/log /mnt/boot; do
  mountpoint -q "$path" && { echo "$path is already mounted. Inspect existing mounts; do not rerun." >&2; exit 1; }
done
for dev in "$ROOT" "$BOOT"; do
  if findmnt -rn -S "$dev" | grep -q .; then
    echo "$dev is mounted elsewhere; unmount it explicitly before starting." >&2; exit 1
  fi
done
mkdir -p /mnt
mount -o subvolid=5 "$ROOT" /mnt
cleanup_top() {
  if [[ "${TOP_MOUNTED:-0}" == 1 ]]; then umount /mnt || true; fi
}
TOP_MOUNTED=1
trap cleanup_top EXIT
# The target must be *empty* after the user's intentional format. Protect any existing data.
[[ -z "$(ls -A /mnt)" ]] || { echo 'p7 contains files/subvolumes already; refusing to create new layout.' >&2; exit 1; }
[[ -z "$(btrfs subvolume list /mnt)" ]] || { echo 'p7 contains Btrfs subvolumes already; refusing to modify.' >&2; exit 1; }
echo 'Creating only four subvolumes on verified EMPTY NIXOS-BTRFS p7.'
for s in @root @home @nix @log; do btrfs subvolume create "/mnt/$s"; done
umount /mnt
TOP_MOUNTED=0
trap - EXIT
mount -o subvol=@root,compress=zstd:3,noatime "$ROOT" /mnt
mkdir -p /mnt/home /mnt/nix /mnt/var/log /mnt/boot
mount -o subvol=@home,compress=zstd:3,noatime "$ROOT" /mnt/home
mount -o subvol=@nix,compress=zstd:3,noatime "$ROOT" /mnt/nix
mount -o subvol=@log,compress=zstd:3,noatime "$ROOT" /mnt/var/log
mount "$BOOT" /mnt/boot
printf '\nMounts prepared. Verify:\n'
findmnt -R /mnt
printf '\nThen run: sudo bash ./03_bootstrap_nixos_live.sh\n'
