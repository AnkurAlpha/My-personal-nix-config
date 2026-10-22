# Virtualization & Containers — dormant by default

The entire `my.system.virtualization` category and each of its five optional
features are initially **disabled** in `hosts/ankur-laptop/virtualization.nix`.
Simply importing this module installs no container runtimes or VM software,
enables no new daemon, and changes no user group membership.

Docker was already configured before this module. Its existing switch is:

`my.apps.development.docker.enable = false;`

in `hosts/ankur-laptop/applications.nix`. This module intentionally does not
provide a competing Docker switch. Docker group membership grants near-root
privileges, so opt in only when needed.

## Opt in later

1. Edit `hosts/ankur-laptop/virtualization.nix`.
2. Set `enable = true;` and only the tool(s) you need to `true`.
3. For VM management, typically enable both `qemuKvm` and `virtManager`.
4. For Distrobox, enable Podman or the existing Docker switch first.
5. Run `nh os build ~/nixos-config -H ankur-laptop`, then
   `nh os switch ~/nixos-config -H ankur-laptop`.
6. Log out/in if you opt into libvirtd group membership.

Nothing mounts, modifies or copies files from `/mnt/garuda`.
No USB/PCI passthrough, VM bridges, or firewall ports are enabled here.
