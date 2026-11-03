# Garuda-inspired extras on NixOS

This is **NixOS**, not Garuda Linux. It adopts selected Garuda-like
features without Arch/pacman settings or a replacement kernel.

## Modules

- `hosts/nixos/garuda-extras.nix`: existing switchable power profiles.
- `hosts/nixos/garuda-system-goodies.nix`: irqbalance, Ananicy C++,
  GameMode, periodic NVMe TRIM, NVMe I/O scheduler and zram.
- `hosts/nixos/garuda-terminal-goodies.nix`: Fish syntax colors and
  system-wide Kitty palette defaults in `/etc/xdg/kitty/kitty.conf`.
  Home Manager does **not** enable Kitty in this host, and an existing
  personal `~/.config/kitty/kitty.conf` can override the system palette.

Ananicy adjusts process priorities; irqbalance distributes hardware
interrupts. Neither replaces the Linux CPU scheduler. To avoid competing
nice adjustments, GameMode's renice feature is disabled by default.
Don't enable aggressive GPU clocks or force performance mode on battery.

## Test

```bash
cd ~/nixos-config
nix build --no-link '.#nixosConfigurations.nixos.config.system.build.toplevel'
nh os test . -H nixos
systemctl is-active irqbalance
systemctl is-active ananicy-cpp || systemctl is-active ananicy
gamemoderun true
systemctl list-timers --all | grep fstrim
powerprofilesctl get
```

For an optional deeper GameMode diagnostic, run `gamemoded -t` and inspect
`journalctl --user -u gamemoded.service` if it reports issues. GameMode
may conflict with other tools that change game process priorities.

For a Steam game, add `gamemoderun %command%` to Launch Options. These
optimizations apply to the particular game, not every desktop app.

After reboot:

```bash
swapon --show
cat /sys/block/nvme0n1/queue/scheduler
findmnt -o TARGET,OPTIONS /
```

The NVMe scheduler rule applies on device initialization, so the result
is most reliable after reboot. ZRAM may also require a fresh boot.
Ananicy and GameMode are optional; remove their module import to revert.
For a temporary system rollback, use `sudo nixos-rebuild switch --rollback`,
then revert the source config before the next build.

**Portability:** this host remains machine-specific. Avoid blindly
copying storage devices, UUIDs or hardware config to a different PC.
