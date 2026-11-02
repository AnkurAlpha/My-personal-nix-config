#!/usr/bin/env bash
# LAST STEP ONLY: run from Garuda after the new NixOS installation has completed.
# Adds only an explicit NixOS GRUB chainload entry; does not reinstall GRUB or change UEFI order.
set -Eeuo pipefail
[[ "$(id -u)" == 0 ]] || { echo 'Run via sudo on Garuda Linux.' >&2; exit 1; }
for cmd in blkid grub-mkconfig mount umount findmnt grep; do
  command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 1; }
done
[[ "$(findmnt -n -o FSTYPE -T /)" == btrfs ]] || { echo 'Root is not Btrfs; check that you are booted into Garuda.' >&2; exit 1; }
[[ "$(blkid -s LABEL -o value /dev/nvme0n1p6)" == NIXBOOT ]] || { echo 'p6 is not NIXBOOT; aborting.' >&2; exit 1; }
[[ -f /boot/grub/grub.cfg && -f /etc/grub.d/40_custom && -x /etc/grub.d/40_custom ]] || { echo 'Expected executable Garuda GRUB 40_custom or grub.cfg not found.' >&2; exit 1; }
[[ ! -e /mnt/nixos-boot-check ]] || { echo 'Temporary inspection path occupied; check first.' >&2; exit 1; }
mkdir -p /mnt/nixos-boot-check
cleanup() { umount /mnt/nixos-boot-check >/dev/null 2>&1 || true; rmdir /mnt/nixos-boot-check >/dev/null 2>&1 || true; }
trap cleanup EXIT
mount -o ro /dev/nvme0n1p6 /mnt/nixos-boot-check
[[ -f /mnt/nixos-boot-check/EFI/systemd/systemd-bootx64.efi ]] || { echo 'Systemd-boot executable not found on p6.' >&2; exit 1; }
find /mnt/nixos-boot-check/loader/entries -maxdepth 1 -name 'nixos-generation-*.conf' -print | grep -q . || { echo 'No NixOS generation found.' >&2; exit 1; }
UUID="$(blkid -s UUID -o value /dev/nvme0n1p6)"
[[ "$UUID" =~ ^[A-Fa-f0-9-]+$ ]] || { echo 'Unexpected FAT32 filesystem UUID.' >&2; exit 1; }
if grep -q 'BEGIN NIXOS P6 CHAINLOAD ENTRY' /etc/grub.d/40_custom; then
  echo 'NixOS custom entry already exists. Not duplicating.'
  exit 0
fi
backup="/etc/grub.d/40_custom.backup-$(date +%Y%m%d-%H%M%S)"
cp -a /etc/grub.d/40_custom "$backup"
printf '\n# BEGIN NIXOS P6 CHAINLOAD ENTRY\n' >> /etc/grub.d/40_custom
cat >> /etc/grub.d/40_custom <<EOF
menuentry 'NixOS (Btrfs, systemd-boot)' --class nixos {
    insmod part_gpt
    insmod fat
    search --no-floppy --fs-uuid --set=root $UUID
    chainloader /EFI/systemd/systemd-bootx64.efi
}
# END NIXOS P6 CHAINLOAD ENTRY
EOF
if ! grub-mkconfig -o /boot/grub/grub.cfg; then
  cp -a "$backup" /etc/grub.d/40_custom
  echo 'Failed to regenerate GRUB; restored 40_custom from backup. Inspect grub.cfg before rebooting.' >&2
  exit 1
fi
echo "NixOS chainload entry installed. Backup: $backup"
echo 'Check whether Garuda GRUB also includes Windows; do not remove an existing Windows entry.'
if ! grep -Eiq "menuentry .*Windows" /boot/grub/grub.cfg; then
  echo 'NOTICE: Windows was not detected in grub.cfg; verify the existing Windows GRUB entry separately.' >&2
fi
