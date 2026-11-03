# Safe installation from a NixOS live USB

## Supported workflow and limits

Use an official **x86_64 NixOS live USB**, booted in the intended firmware mode.
The installer supports new minimal/Hyprland machines with explicit GPU selection.
It requires Python 3, Git, Nix and the NixOS live installation tools. It refuses to
run an installation on an ordinary non-NixOS system or where it cannot confirm
an installer environment. It never reboots automatically.

| Mode | Target preparation | Writes made by the workflow |
| --- | --- | --- |
| Default `prepared` plan | You mount root at `/mnt`, ESP at `/mnt/boot` for UEFI | Read-only checks/output only; no hardware/host files written |
| `prepared --install` | Same, newly prepared root/subvolumes | New target repo, generated host, Nix store/system files and reviewed bootloader writes |
| `fresh` plan | Explicit existing empty Btrfs root and FAT32 boot devices | No mounts or writes; reports proposed choices |
| `fresh --install` | Filesystems must already exist; root must be empty | Read-only empty-root probe, typed preparation confirmation, four subvolumes/mounts, then install |

**There is no automatic partition, erase or format mode.** Fresh installation
means installing onto a new empty filesystem that you intentionally prepared in a
partition manager. The installer does not choose a disk to wipe. Unsupported
storage, boot or existing-data conditions stop with an explanation rather than
falling back to a guessed layout. Physical boot success has not been tested by
the repository audit; complete the hardware checklist below.

Btrfs uses `@root`, `@home`, `@nix`, `@log`, compression `zstd:3` and `noatime` in
fresh mode. Prepared mode accepts Btrfs/ext4/XFS root filesystems and existing
explicit mounts. Encryption, LVM/RAID, unusual ESP layouts, external GPU/mux
arrangements and Secure Boot need manual planning/review; the tool does not
create encryption, recovery keys or signing enrollment. It supports x86_64 only.

## Before booting the USB

Back up projects, home data, private keys, browser profiles, credentials and any
other OS's recovery keys to another device. Confirm you can restore important
files. Download and verify an appropriate official ISO from
[NixOS downloads](https://nixos.org/download/). Create the USB using a trusted image
writer after verifying the exact **USB** device in that application's UI. The
repository does not flash a USB or supply an unattended `dd` command.

For dual/triple boot, document the current disk layout and firmware entries.
Windows BitLocker/device encryption may need its recovery key after boot changes.
Do not resize/delete/format existing OS partitions as an incidental install step.
Partition resizing is a separate operation with its own backup and recovery plan.

## Boot, network and inventory

```bash
# UEFI boots expose this directory. Absence means legacy mode.
test -d /sys/firmware/efi && echo UEFI || echo LEGACY
lsblk -o NAME,PATH,SIZE,MODEL,FSTYPE,LABEL,UUID,MOUNTPOINTS
sudo parted -l
ip -brief address
```

Connect with the graphical network UI or the live image's network tools. Do not
put Wi-Fi passwords in shell history or Git. Enter a temporary tools shell:

```bash
nix-shell -p git python3
# Include btrfs-progs if you need it and it is not already present.
git clone https://github.com/AnkurAlpha/My-personal-nix-config.git
cd My-personal-nix-config
```

The `sudo env "PATH=$PATH"` form retains the temporary tools shell's Python/Git
paths across privilege elevation; it does not put passwords in arguments.

A fork is preferable for publishing your own host. The installer keeps the source
checkout unchanged and clones it into the target, so the source must be clean and
committed. It verifies a Git network request before installation; Nix input/cache
failures are still possible and stop the subsequent evaluation/build.

The disk inventory reports possible Windows/Linux/data filesystems and EFI
partitions without mounting unselected volumes. Filesystem type alone cannot
prove an OS is absent. Inspect labels, device model, size, partition table and
existing boot files yourself. Never interpret an empty detection result as an
erasure authorization.

## Path A: already prepared and mounted partitions

Prepare the new root/boot filesystems manually after checking backups and exact
devices. The tool will not create them. Mount the chosen root at `/mnt`; if Btrfs,
mount the intended root subvolume and any separate home/nix/log subvolumes. For
UEFI, mount its FAT32 ESP at `/mnt/boot`, matching the generated boot policy.
Inspect `findmnt -R /mnt`.

Mount-only Bash example for **already prepared** devices/subvolumes:

```bash
read -r -p 'Actual Btrfs root partition path: ' ROOT_DEV
read -r -p 'Actual FAT32 ESP partition path: ' EFI_DEV
lsblk -f "$ROOT_DEV" "$EFI_DEV"
# Check these are the intended devices before mounting.
sudo mount -o subvol=@root,compress=zstd:3,noatime "$ROOT_DEV" /mnt
sudo mkdir -p /mnt/home /mnt/nix /mnt/var/log /mnt/boot
sudo mount -o subvol=@home,compress=zstd:3,noatime "$ROOT_DEV" /mnt/home
sudo mount -o subvol=@nix,compress=zstd:3,noatime "$ROOT_DEV" /mnt/nix
sudo mount -o subvol=@log,compress=zstd:3,noatime "$ROOT_DEV" /mnt/var/log
sudo mount -o fmask=0077,dmask=0077 "$EFI_DEV" /mnt/boot
findmnt -R /mnt
```

These commands do not create missing subvolumes and are not a formatting recipe.
For ext4/XFS, mount the prepared root with appropriate options and a distinct ESP;
do not use Btrfs `subvol` options. A separate `/home` containing personal data is
refused by the automatic workflow; migrate it manually after a fresh installation.
The installer also refuses an existing OS root or unrelated `/etc` configuration.

Plan and install an AMD desktop/laptop example:

```bash
sudo env "PATH=$PATH" bash scripts/install.sh --host newpc --username alice \
  --graphics amd --desktop hyprland --timezone Asia/Kolkata
sudo env "PATH=$PATH" bash scripts/install.sh --host newpc --username alice \
  --graphics amd --desktop hyprland --timezone Asia/Kolkata --install
```

The first command does not install. The second verifies the live environment,
mounts, free space, network and source checkout, then asks for an exact phrase at
the **local terminal**. It cannot be approved by piping `yes` or adding a generic
unattended flag. No prior chat approval substitutes for this local disk/boot review.

## Path B: fresh Btrfs subvolume preparation

First create the intended partitions/filesystems manually, using a partition
manager and explicit local disk confirmation. Root must be a completely empty
Btrfs filesystem; boot must already be FAT32. A previously used Btrfs volume with
any files or subvolumes is refused. Neither selected device may already be mounted.
Do not point these variables at the original laptop's partitions merely because
an older guide uses those names.

```bash
read -r -p 'Actual empty Btrfs partition path: ' ROOT_DEV
read -r -p 'Actual FAT32 ESP partition path: ' EFI_DEV
lsblk -f "$ROOT_DEV" "$EFI_DEV"
sudo env "PATH=$PATH" bash scripts/install.sh --mode fresh --host newpc --username alice \
  --graphics intel --desktop hyprland --root-device "$ROOT_DEV" --boot-device "$EFI_DEV"
# Repeat after review, adding --install:
sudo env "PATH=$PATH" bash scripts/install.sh --mode fresh --host newpc --username alice \
  --graphics intel --desktop hyprland --root-device "$ROOT_DEV" --boot-device "$EFI_DEV" --install
```

Fresh mode probes the Btrfs top level read-only, always unmounts its own probe,
then requires `PREPARE <exact-root-device> WITH EFI <exact-boot-device>`. It creates
only the four documented subvolumes, mounts them, then performs the normal install
checks and a separate installation confirmation. It does not delete pre-existing
subvolumes. If preparation is interrupted, inspect `findmnt -R /mnt` and the
created subvolumes; complete mounting manually and use prepared mode. Repeating
fresh mode over partly prepared storage intentionally stops instead of guessing.

## GPU, profile and boot selection

Choose one of `none`, `intel`, `amd`, `intel-nvidia`, `amd-nvidia`, `nvidia`.
Hybrid NVIDIA needs both `--integrated-bus-id` and `--nvidia-bus-id`, in verified
decimal NixOS PCI format. See the [GPU guide](GAMING_AND_GRAPHICS.md) before choosing
open/closed modules or reusing bus IDs. Add `--gaming`, `--bluetooth`,
`--power-profiles` only when appropriate. No laptop power profile, NVIDIA helper,
personal Git identity or data mount is automatically copied to every machine.

UEFI installations use systemd-boot and do not change firmware variables by
default. This does **not** mean no EFI files change: systemd-boot writes its own
loader files and can update `EFI/BOOT/BOOTX64.EFI`. Use a dedicated ESP when
possible. An occupied ESP is refused unless you explicitly add
`--allow-shared-esp`, back it up, review displayed EFI files and confirm a phrase
ending `UPDATE SHARED EFI`. Other vendors' directories are not intentionally
removed, but existing fallback-loader content can be replaced. Check shared ESP
capacity; the tool requires at least 256 MiB free, and several retained kernels
can require more. Filesystem type FAT32 alone does not prove a correct ESP type;
verify its EFI partition flag/type in the partition manager.

With `canTouchEfiVariables = false`, select the correct EFI file/entry using your
firmware or configure your existing boot manager manually. The script does not
promise that an arbitrary Garuda/Windows boot manager automatically discovers
NixOS. Do not run the original laptop's `04_garuda_grub_nixos_entry.sh` on another
computer. It assumes fixed p6 and modifies Garuda's GRUB configuration.

Legacy BIOS is prepared-mode only. Boot the USB in legacy mode; supply
`--boot legacy --disk /dev/ACTUAL_WHOLE_DISK` after checking the disk's identity.
The root must be on that disk. GPT needs a BIOS Boot Partition; MBR needs suitable
bootloader space. The final phrase explicitly names `REPLACE GRUB ON <disk>`.
This replaces boot code and can affect another OS's boot path; use a separately
reviewed multi-boot plan. No partition/format operation is performed.

## What happens after confirmation

1. The source is cloned into `/mnt/etc/nixos-config`, without overwriting an
   existing target directory. No private home, keys or password files are copied.
2. `nixos-generate-config --root /mnt --show-hardware-config` supplies fresh
   hardware data without replacing an existing `/mnt/etc/nixos` file.
3. The same host generator creates `hosts/NEW_HOST/` in the target checkout and
   stages its files for Git-flake visibility. Registration is automatic.
4. Nix evaluates the hostname and all assertions, then builds
   `nixosConfigurations.NEW_HOST.config.system.build.toplevel` with the lock fixed.
5. Only after a successful build does `nixos-install --root /mnt --flake ...` run.
6. `nixos-install` prompts for the root password; `nixos-enter` then runs
   `passwd USER` locally for the regular user's password. No password argument,
   plaintext password, hash, SSH key or secret is written to Git.

Build failures leave the new target checkout available for diagnosis and do not
run `nixos-install`. No automatic rollback, unmount, garbage collection or reboot
runs on failure. `--resume` accepts only an identical installer-managed target
with matching source revision, root mount source and host choices; differing or
unmanaged directories are refused. Resume is for staging/build failures; if a
partial OS already exists, repair manually from the live USB instead of asking the
generator to overwrite it. Password failures after installation also need manual
`nixos-enter ... -c 'passwd USER'` recovery before rebooting.

## Before reboot and first login

```bash
findmnt -R /mnt
sudo ls /mnt/boot/loader/entries    # UEFI systemd-boot case
sudo git -C /mnt/etc/nixos-config status --short
```

Review the new host/hardware files, target boot files and firmware boot selection.
Keep the live USB. Once ready, leave the target directory, flush writes, unmount
child mounts safely and reboot manually. Do not unmount the live USB or an
unrelated partition through a copied generic device command.

On first login, `/etc/nixos-config` is the installed working checkout and `nh`
points there. It is initially root-owned; edit deliberately using `sudoedit`, or
transfer ownership of this exact checkout to your regular user if you want a
user-maintained configuration. Do not recursively chown `/etc` itself. Git may
require using `sudo git -C /etc/nixos-config ...` until ownership is chosen.

```bash
hostname
findmnt -R / -o TARGET,SOURCE,FSTYPE,OPTIONS
systemctl --failed
journalctl -b -u display-manager --no-pager
# For supported NVIDIA selections only:
nvidia-smi
```

Minimal profile logs into a TTY. Hyprland profile uses SDDM; Super+Enter opens
Kitty, Super+D Wofi, Super+Q closes the focused window. Add your desired theme,
Waybar, shell and applications after validating the baseline. Preserve
`system.stateVersion` and HM state version after this first installation.
Commit reviewed generated host files, then push to your fork/review branch after
real-machine verification. Back up the working host and important mutable data.

## Recovery checklist

If login/graphics fails, try a TTY and inspect `journalctl -b -u display-manager`.
After later configuration updates, an older generation can be selected at boot;
rollback is not a substitute for a bootloader/ESP backup. If NixOS never booted,
use the USB and verify firmware mode, ESP mount/type, loader path, root UUID,
subvolume names, initrd and selected driver. Do not change disk layout blindly.
Unsupported GPUs/firmware may require manual configuration even if evaluation
passes. The audit has not claimed physical installation, suspend or boot tests.

References: [NixOS installation manual](https://nixos.org/manual/nixos/stable/#sec-installation),
[hardware generation](https://wiki.nixos.org/wiki/Nixos-generate-config),
[Btrfs](https://wiki.nixos.org/wiki/Btrfs).
