#!/usr/bin/env bash
# Stage 2: run ONLY from a NixOS live USB after manual Btrfs partitioning/mounting.
# No mkfs, resize, partition deletion, or boot-order changes are performed here.
set -Eeuo pipefail
DEST=/mnt
ROOT_DEVICE=/dev/nvme0n1p7
BOOT_DEVICE=/dev/nvme0n1p6
REPO_URL=https://github.com/AnkurAlpha/My-personal-nix-config.git
HOST=nixos

fatal() { echo "ERROR: $*" >&2; exit 1; }
info() { echo; echo "==> $*"; }
[[ "$(id -u)" == 0 ]] || fatal 'Run as root via sudo: sudo bash ./03_bootstrap_nixos_live.sh'
command -v nixos-install >/dev/null || fatal 'This is not a NixOS installation environment (missing nixos-install).'
for cmd in lsblk findmnt nixos-generate-config nixos-enter nix; do
  command -v "$cmd" >/dev/null || fatal "Missing command: $cmd"
done
SOURCE_REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TARGET_USER="$(nix --extra-experimental-features 'nix-command flakes' eval --raw "$SOURCE_REPO#nixosConfigurations.$HOST.config.my.user.name")"
[[ "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]{0,30}$ && "$TARGET_USER" != root ]] || fatal 'Invalid configured regular username.'
TARGET_HOME="$(nix --extra-experimental-features 'nix-command flakes' eval --raw "$SOURCE_REPO#nixosConfigurations.$HOST.config.my.user.homeDirectory")"
[[ "$TARGET_HOME" == "/home/$TARGET_USER" ]] || fatal 'Legacy reinstall requires the regular /home/USER layout; use the universal workflow for another layout.'
TARGET_REPO="/mnt$TARGET_HOME/nixos-config"
[[ -b "$ROOT_DEVICE" && -b "$BOOT_DEVICE" ]] || fatal 'Expected p7 (NixOS) and p6 (NIXBOOT) block devices.'
[[ "$(lsblk -dn -o FSTYPE "$ROOT_DEVICE" | tr -d '[:space:]')" == btrfs ]] || fatal 'p7 is not Btrfs. Do not autoformat; finish partitioning separately.'
[[ "$(lsblk -bn -o SIZE "$ROOT_DEVICE" | tr -d '[:space:]')" -ge $((145 * 1024 * 1024 * 1024)) ]] || fatal 'p7 is below 145 GiB; not the requested 150/200 GiB NixOS layout.'
[[ "$(lsblk -dn -o FSTYPE "$BOOT_DEVICE" | tr -d '[:space:]')" == vfat ]] || fatal 'p6 must remain a FAT32 boot filesystem.'
for point in /mnt /mnt/home /mnt/nix /mnt/var/log /mnt/boot; do
  mountpoint -q "$point" || fatal "Expected mounted subvolume/filesystem: $point"
done
# Compare actual mount SOURCE to the disk devices, not MAJ:MIN.
# Btrfs subvolumes have a virtual MAJ:MIN (e.g. 0:66), unlike p7 (259:6).
for point in /mnt /mnt/home /mnt/nix /mnt/var/log; do
  actual=$(findmnt -n -o SOURCE --mountpoint "$point")
  device=${actual%%\[*}
  [[ "$(readlink -f "$device")" == "$(readlink -f "$ROOT_DEVICE")" ]] || fatal "$point is not on NixOS p7 (found $actual)"
done
boot_source=$(findmnt -n -o SOURCE --mountpoint /mnt/boot)
[[ "$(readlink -f "$boot_source")" == "$(readlink -f "$BOOT_DEVICE")" ]] || fatal '/mnt/boot is not NIXBOOT p6.'
for pair in '/mnt @root' '/mnt/home @home' '/mnt/nix @nix' '/mnt/var/log @log'; do
  read -r mnt subvol <<< "$pair"
  opts=$(findmnt -no OPTIONS -T "$mnt")
  [[ "$opts" == *"subvol=/$subvol"* || "$opts" == *"subvol=$subvol"* ]] || fatal "$mnt must mount Btrfs subvolume $subvol; got: $opts"
done
# Garuda p5 must never be mounted under target /mnt.
[[ ! -e /mnt/boot/efi/.garuda-marker ]] || fatal 'Unexpected EFI mount.'
if mountpoint -q /mnt/boot/efi; then fatal 'Shared Garuda/Windows EFI partition must not be mounted inside target NixOS.'; fi
if [[ -e "$TARGET_REPO" && ! -d "$TARGET_REPO/.git" ]]; then
  fatal "Target path exists but isn't a Git repo: $TARGET_REPO"
fi
info 'Preflight summary (read carefully)'
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS /dev/nvme0n1
findmnt -R /mnt
printf '\nGaruda p5 and Windows p1-p4 will not be formatted or changed.\n'
info 'Clone exact GitHub configuration with the new nixos host'
mkdir -p "/mnt$TARGET_HOME"
if [[ -d "$TARGET_REPO/.git" ]]; then
  echo 'Using existing target repo from a previous interrupted installation; not recloning.'
  if command -v git >/dev/null; then
    [[ "$(git -C "$TARGET_REPO" remote get-url origin)" == "$REPO_URL" ]] || fatal 'Unexpected target repo origin; review manually.'
  fi
elif command -v git >/dev/null; then
  git clone --branch main "$REPO_URL" "$TARGET_REPO"
else
  command -v nix-shell >/dev/null || fatal 'Git and nix-shell are both missing.'
  nix-shell -p git --run "git clone --branch main '$REPO_URL' '$TARGET_REPO'"
fi
[[ -f "$TARGET_REPO/flake.nix" && -f "$TARGET_REPO/flake.lock" ]] || fatal 'Clone lacks flake files.'
[[ -f "$TARGET_REPO/hosts/nixos/configuration.nix" ]] || fatal 'The remote lacks hosts/nixos/configuration.nix; publish the intended source revision before reinstalling.'
if grep -Rqs 'ankur-laptop' "$TARGET_REPO/hosts/nixos" "$TARGET_REPO/flake.nix"; then
  fatal 'Old hostname references remain. Fix repository and retry after checking staged files.'
fi
# Migration-only safety: the evaluated flake option is checked below.
info 'Generate filesystem/hardware configuration for the NEW Btrfs UUID'
nixos-generate-config --root "$DEST"
GENERATED=/mnt/etc/nixos/hardware-configuration.nix
[[ -s "$GENERATED" ]] || fatal 'nixos-generate-config did not create a hardware file.'
[[ $(grep -Fc 'fsType = "btrfs"' "$GENERATED") -ge 1 ]] || fatal 'Generated hardware config does not contain Btrfs mounts.'
[[ $(grep -Fc 'fsType = "vfat"' "$GENERATED") -ge 1 ]] || fatal 'Generated hardware config does not contain NIXBOOT mount.'
# Only replace the hardware file that the actual repo host uses.
HARDWARE="$TARGET_REPO/hosts/nixos/hardware-configuration.nix"
if [[ ! -f "$HARDWARE" ]]; then
  fatal "No $HARDWARE. Inspect the host imports and copy the generated file to the actual imported path manually before installing."
fi
# Safety: insist host module imports the hardware file by relative path.
if ! grep -Eq '(\./hardware-configuration\.nix|hardware-configuration\.nix)' "$TARGET_REPO/hosts/nixos/configuration.nix"; then
  fatal 'Cannot verify hardware-configuration.nix import in host config. Do not install yet.'
fi
cp "$GENERATED" "$HARDWARE"
# NIXBOOT_RANDOM_SEED_MASKS_HARDENED: FAT32 /boot must not expose systemd-boot random seed.
sed -i 's/"fmask=0022" "dmask=0022"/"fmask=0077" "dmask=0077"/' "$HARDWARE"
grep -Fq '"fmask=0077" "dmask=0077"' "$HARDWARE" || fatal 'Expected restrictive NIXBOOT FAT32 mount masks are missing.'
# Stage updated hardware file so local Git-backed flakes see it, without pushing changes.
if command -v git >/dev/null; then
  git -C "$TARGET_REPO" add hosts/nixos/hardware-configuration.nix
else
  nix-shell -p git --run "git -C '$TARGET_REPO' add hosts/nixos/hardware-configuration.nix"
fi
info 'Evaluate new NixOS hostname before actual install'
nix --extra-experimental-features 'nix-command flakes' eval --raw \
  "$TARGET_REPO#nixosConfigurations.$HOST.config.networking.hostName" | grep -qx "$HOST" \
  || fatal 'Flake did not evaluate to networking.hostName = nixos.'
info 'Verify bootloader stays on NIXBOOT, Garuda UEFI priority untouched'
[[ "$(nix --extra-experimental-features 'nix-command flakes' eval --raw "$TARGET_REPO#nixosConfigurations.$HOST.config.boot.loader.efi.efiSysMountPoint")" == '/boot' ]] || fatal 'NixOS EFI mount point is not /boot; not safe for Garuda EFI.'
[[ "$(nix --extra-experimental-features 'nix-command flakes' eval --json "$TARGET_REPO#nixosConfigurations.$HOST.config.boot.loader.efi.canTouchEfiVariables")" == false ]] || fatal 'canTouchEfiVariables must be false before installation.'
[[ "$(nix --extra-experimental-features 'nix-command flakes' eval --json "$TARGET_REPO#nixosConfigurations.$HOST.config.boot.loader.systemd-boot.enable")" == true ]] || fatal 'Expected systemd-boot to remain enabled on p6.'
info 'Check Home Manager integrated in the NixOS configuration'
if nix --extra-experimental-features 'nix-command flakes' eval --raw "$TARGET_REPO#nixosConfigurations.$HOST.config.home-manager.users.\"$TARGET_USER\".home.username" | grep -qx "$TARGET_USER"; then
  echo 'Home Manager is integrated: it will be applied by nixos-install.'
else
  fatal "Home Manager is not integrated for $TARGET_USER; inspect flake before installing."
fi
info 'Install flake (including integrated Home Manager)'
nixos-install --flake "$TARGET_REPO#$HOST" --option max-jobs 1 --option cores 2
info "Set the $TARGET_USER user password (NixOS login)"
nixos-enter --root /mnt -c "passwd $TARGET_USER"
info 'Fix repository ownership inside installed NixOS'
nixos-enter --root /mnt -c "chown -R -- $TARGET_USER:users $TARGET_HOME/nixos-config"
echo
info 'NixOS installed. Before reboot: verify /mnt/boot/loader/entries/ and keep your live USB ready.'
echo 'Garuda GRUB integration is a separate step: it is not modified by this installer.'
echo 'Git changes from generated hardware configuration are not auto-pushed; commit/push after first boot.'
