# Installing on another PC

The supported general workflow is now in [Universal installation](INSTALLATION.md).
It covers official live USB preparation, disk/EFI safety, prepared partitions,
fresh Btrfs subvolume creation, credentials, recovery and first login.

Use [Additional hosts](HOSTS.md) for standalone host generation and manual
customization. The new generator creates a new host with freshly generated
hardware; `lib/hosts.nix` registers it automatically once its files are staged.
Do **not** copy the complete `hosts/nixos/` directory: it contains the original
laptop's UUIDs, GPU addresses, username, networking and personal mount choices.

Earlier versions of this guide described a manual host-directory copy. Its useful
mounting, backup, hardware-generation and multi-boot review steps are integrated
into the installation guide. The automatic workflow avoids the unsafe assumption
that replacing only hardware-configuration.nix makes the personal host portable.

The separate [original-laptop Btrfs reinstall](NIXOS_BTRFS_REINSTALL.md) and
[fixed-device scripts](../scripts/reinstall-nixos/README.md) remain for their
historical machine-specific scope. Never use their hard-coded partition names on
another computer. Git and NixOS generations cover configuration, not private data;
keep off-device backups of home data, keys, credentials and boot recovery files.
