# Documentation index

Start with the [root README](../README.md), then choose the relevant guide.
All configuration descriptions refer to this checkout; runtime verification is
separate and its limits are recorded in the audit report.

| Guide | Contents |
| --- | --- |
| [Architecture](ARCHITECTURE.md) | Import graph, option merging and module reference |
| [Full file tree](REPOSITORY_TREE.md) | Actual configuration/tool/document inventory |
| [Software and modules](MODULE_MANAGEMENT.md) | Install/remove packages, switches, imports and module development |
| [Commands and recovery](COMMANDS.md) | Nix, nh, generations, store, services and Git |
| [Universal installation](INSTALLATION.md) | Live USB, prepared/fresh Btrfs, disk/EFI safety and recovery |
| [Additional hosts](HOSTS.md) | Host creation, usernames, hardware and profile selection |
| [Gaming and graphics](GAMING_AND_GRAPHICS.md) | GameMode, Steam launch options and GPU matrix |
| [Garuda-inspired features](GARUDA_GOODIES_ON_NIXOS.md) | Power, scheduling, storage, ZRAM and appearance |
| [Desktop and Home Manager](DESKTOP_AND_HOME_MANAGER.md) | Hyprland, Waybar, Fish, Kitty, appearance and ownership |
| [Maintenance](MAINTENANCE.md) | Btrfs, TRIM, ZRAM, update helpers and cleanup |
| [Verification report](AUDIT_REPORT.md) | Changes, executed checks, findings and unverified hardware |
| [Another PC](NIXOS_INSTALL_ON_ANOTHER_PC.md) | Migration note pointing to the supported universal workflow |
| [Original laptop Btrfs reinstall](NIXOS_BTRFS_REINSTALL.md) | Historical partition-specific procedure, not portable |
| [Original reinstall scripts](../scripts/reinstall-nixos/README.md) | Fixed-device scripts, prerequisites and scope |
| [New-host template](../hosts/templates/README.md) | Generator and manual registration pattern |
| [Developer environments](development-environments/README.md) | Per-language flake shells and Direnv |
| [Academics](academics/README.md) | Licensed MATLAB launcher and RStudio |
| [Office](office/README.md) | Per-application document tools |
| [Desktop customization](desktop-customization/README.md) | Optional GUI utilities |
| [GTK and Qt](desktop-customization/GTK-QT-THEMING.md) | Sweet assets and Qt/Kvantum settings |
| [Performance](performance-tuning/README.md) | Current ZRAM and optional tuning |
| [Printing and peripherals](printing-peripherals/README.md) | CUPS, scanners, phones and USB |
| [Storage integrations](storage-filesystems/README.md) | Filesystem tools and optional automounting |
| [Security and privacy](security-privacy/README.md) | Opt-in security integrations |
| [Virtualization](virtualization/README.md) | Containers, libvirtd and users/groups |
| [Zellij](../home/ankur/zellij/README.md) | Terminal multiplexer config and launch binding |

Upstream references: [NixOS manual](https://nixos.org/manual/nixos/stable/),
[Nix manual](https://nix.dev/manual/nix/stable/),
[Home Manager manual](https://nix-community.github.io/home-manager/),
[nh](https://github.com/nix-community/nh),
[GameMode](https://github.com/FeralInteractive/gamemode),
[Btrfs documentation](https://btrfs.readthedocs.io/en/latest/).
For option availability, the pinned inputs in this checkout are authoritative;
current upstream documentation may describe newer versions.
