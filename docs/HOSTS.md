# Additional computers and host generation

The original `nixos` host remains unchanged in identity and hardware. New hosts
live at `hosts/NAME/configuration.nix` with their own generated hardware file.
`lib/hosts.nix` discovers these directories and `flake.nix` merges their outputs
with the explicit laptop and ISO definitions. **No per-host edit to `flake.nix`
is required for generated hosts.** Add new files to Git before evaluating.

## Generate a host from the target computer

Boot the target's NixOS live USB, prepare/mount its filesystems, then print hardware
configuration without replacing any existing configuration file:

```bash
sudo nixos-generate-config --root /mnt --show-hardware-config > /tmp/hardware-configuration.nix
bash scripts/new-host.sh --host workpc --username alice \
  --hardware /tmp/hardware-configuration.nix --root-fs btrfs \
  --graphics amd --desktop hyprland --timezone Asia/Kolkata
```

This is a host-file operation only: it does not mount, format, install, switch,
commit or push. It creates `configuration.nix`, `hardware-configuration.nix` and a
non-secret `machine.json` description. Existing identical output is a no-op;
existing different content is refused. `--dry-run` prints the configuration
without writing. The automatic installer uses this same implementation after
cloning the source into the mounted target.

Choose lowercase hostname labels (letters/digits/hyphens, max 63 characters).
`nixos`, `installer-iso`, `garuda`, `templates` are reserved. Choose a regular Linux
username; no password is written to Git. Current tooling supports x86_64 and new
26.05 state versions. An old system's stateVersion must be preserved/migrated
manually rather than reset with this generator.

## Profiles and hardware choices

| Machine | Suggested options | Additional review |
| --- | --- | --- |
| AMD laptop without NVIDIA | `--graphics amd --desktop hyprland --power-profiles` | Optional Bluetooth, firmware, battery behavior |
| Intel laptop without NVIDIA | `--graphics intel --desktop hyprland --power-profiles` | Optional Bluetooth/video acceleration; no automatic thermald |
| NVIDIA hybrid laptop | `--graphics amd-nvidia` or `intel-nvidia` | Both real decimal PCI bus IDs, supported open/closed driver |
| AMD desktop | `--graphics amd --desktop hyprland` | No laptop power daemon unless explicitly wanted |
| Intel desktop | `--graphics intel --desktop hyprland` | Display outputs and graphics generation |
| NVIDIA desktop | `--graphics nvidia --desktop hyprland` | No PRIME needed for a single GPU |
| VM or minimal server | `--graphics none --desktop minimal` | Actual virtual storage/network devices and appropriate boot mode |

Add `--gaming`, `--bluetooth`, `--power-profiles` only when required. The default is
minimal, no selected GPU, no gaming/Bluetooth/PPD. The Hyprland profile supplies
SDDM, PipeWire and a small HM terminal/launcher/Lua config. It does not copy personal
Waybar/Fish/Git identity/themes, old performance values or the Garuda data mount.
This is an intentional base to customize, not a promise that every machine looks
identical to the original laptop.

Generated `my.machine.*` selections connect to `modules/profiles/machine.nix`,
which imports the small portable package profile and declares optional hybrid
NVIDIA support. Only NVIDIA choices activate NVIDIA drivers/wrappers; ordinary
Intel/AMD choices use native graphics. See [Gaming and graphics](GAMING_AND_GRAPHICS.md).

UEFI uses systemd-boot with ESP at `/boot` and `canTouchEfiVariables = false`.
That avoids changing NVRAM boot order, but the loader still writes EFI files,
including a possible fallback loader; choose firmware entries deliberately.
Legacy mode requires `--boot legacy --disk /dev/ACTUAL_WHOLE_DISK` and a separately
prepared BIOS-compatible disk layout. Do not guess the disk or use a partition as
GRUB's disk target. The installer asks for exact local boot-code replacement
confirmation. Secure Boot is not automatically signed or enrolled.

## Evaluate, build, activate

```bash
git add hosts/workpc
nix eval --json .#nixosConfigurations --apply builtins.attrNames
nix eval --raw .#nixosConfigurations.workpc.config.networking.hostName
nix flake check --no-build --no-update-lock-file
nix build --no-link .#nixosConfigurations.workpc.config.system.build.toplevel
```

Building another host on the current computer does not install it. Do not switch
to another machine's hardware configuration on the original laptop. From the
new machine's live USB, use the [installer](INSTALLATION.md), or after a full manual
mount/configuration review use `sudo nixos-install --root /mnt --flake .#workpc`.
On the **installed workpc itself**, routine changes can use
`nh os test /etc/nixos-config -H workpc` then `nh os switch ...`.

## Manual creation and sharing modules

For custom profiles, create a new directory manually and import:

```nix
{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/machine.nix
  ];
  networking.hostName = "workpc";
  system.stateVersion = "26.05";
  my.machine = { username = "alice"; desktop = "minimal"; graphics = "amd"; };
  # Choose bootloader/mount policy for THIS computer explicitly.
}
```

Supply the newly generated hardware file and bootloader options. Do not install
this incomplete teaching snippet as-is. Automatic registration still works once
staged. If the host root lives outside `hosts/NAME/configuration.nix`, explicitly
add a `nixpkgs.lib.nixosSystem { modules = [ PATH ... ]; };` output in `flake.nix`
instead, with HM integration if needed. Never redefine a reserved output.

Share feature **implementations** under `modules/`; put selections in each host.
Before reusing older modules, search `ankur`, `/home/ankur`, `hosts/nixos`, `wlo1`,
`/mnt/garuda` and GPU-option references. Some optional Docker/libvirtd helpers
still name Ankur and must be parameterized for another username. Hardware file,
disk UUIDs, boot target, GPU bus IDs, interface names and credentials remain local
to the machine. Do not add new hardware by copying the entire `hosts/nixos/` tree.

Keep `machine.json` synchronized if using generator resume/idempotence checks;
after manual edits, regenerating over that host intentionally refuses different
content. Edit existing hosts directly and use Git review rather than using the
generator as an overwrite tool.
