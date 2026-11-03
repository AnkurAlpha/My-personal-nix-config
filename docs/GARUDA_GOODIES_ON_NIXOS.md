# Garuda-inspired features implemented with NixOS

This configuration borrows selected desktop ideas, colors and helper choices from
Garuda Linux. Packages, services, system generation management and maintenance are
implemented with **native NixOS/Home Manager** options. No Arch package manager,
Garuda kernel replacement, BORE scheduler, automatic snapshot system or Garuda
system-updater daemon is installed by these modules.

## Actual owners and current selections

| File | Role / configured state |
| --- | --- |
| `hosts/nixos/garuda-extras.nix` | power-profiles-daemon, no fixed CPU governor; asserts exclusive power backend |
| `hosts/nixos/garuda-system-goodies.nix` | irqbalance, Ananicy C++, GameMode defaults, fstrim, NVMe scheduler, ZRAM defaults |
| `hosts/nixos/garuda-terminal-goodies.nix` | Fish syntax colors and system Kitty default palette |
| `hosts/nixos/performance-tuning.nix` | Explicit ZRAM enable/90% logical capacity and swappiness 180 |
| `modules/system/performance-tuning.nix` | Conditional reusable implementation; other tuning options remain off |
| `hosts/nixos/power-battery.nix`; `modules/system/power-battery.nix` | Read-only diagnostic helper; optional power backends are off here, but PPD is enabled elsewhere |
| `hosts/nixos/btrfs-maintenance.nix` | Monthly scrub of NixOS `/` once per filesystem |
| `hosts/nixos/hardware-configuration.nix` | Btrfs `compress=zstd:3,noatime`, four subvolumes; generated ESP mount |
| `hosts/nixos/gaming.nix`; `home/ankur/applications/gaming.nix` | Steam/GameMode integration, MangoHud and offload helper |
| `home/ankur/hyprland/waybar.nix`; `waybar/scripts/power_profile_menu.sh` | Power-profile display/cycle and Wofi menu |

These are source selections. Confirm runtime state on the laptop using the
commands below. A flag marked false in one module does not cancel another
provider's true definition. No performance improvement was benchmarked in this audit.

## Performance, Balanced and Power Saver

PPD exposes profiles through `powerprofilesctl` and D-Bus. Available modes depend
on firmware/CPU/backend support; some machines do not offer Performance. Balanced
is a general compromise; Power Saver prioritizes lower power; Performance may
increase heat/noise and cannot override all thermal limits. Check availability:

```bash
powerprofilesctl list
powerprofilesctl get
powerprofilesctl set balanced
systemctl status power-profiles-daemon --no-pager
journalctl -b -u power-profiles-daemon --no-pager
```

The Waybar native `power-profiles-daemon` component is inserted before battery.
Left click uses the widget's profile cycle; right click calls the Wofi chooser.
The chooser needs Wofi and `powerprofilesctl`, exits on cancel/missing tools, and
will report a backend failure if a requested profile is unsupported. The icons
for Performance, Balanced and Power Saver remain in `waybar.nix`.

`powerManagement.cpuFreqGovernor = lib.mkForce null` prevents an older fixed
governor from competing with PPD. Do not simultaneously enable TLP, auto-cpufreq
or tuned; the host asserts against them. GameMode can also request CPU policy
changes during games, so inspect effective behavior and logs. A profile's name
is not proof of higher application throughput.

## irqbalance: interrupt affinity, not a CPU scheduler

`services.irqbalance.enable` runs a daemon that can distribute hardware interrupts
across CPU cores. It may help some interrupt-heavy workloads and can make little
difference or be undesirable for deliberately pinned/isolated workloads. It does
not replace the kernel's process scheduler or guarantee lower latency.

```bash
systemctl is-active irqbalance.service
journalctl -b -u irqbalance.service --no-pager
cat /proc/interrupts
```

Compare interrupt distribution over time and benchmark the workload before
changing its policy. The optional performance module's irqbalance flag is false,
but Garuda goodies independently provides a true default.

## Ananicy C++ process-priority rules

The host enables `services.ananicy` and selects `pkgs.ananicy-cpp`. Matching rules
can change nice values, scheduling policy and I/O priority for particular process
names. This is not a replacement CPU scheduler. Background work can yield more
readily, but a poorly chosen rule can delay useful work; measure responsiveness
and task completion time rather than claiming a general speedup.

```bash
systemctl list-unit-files '*ananicy*'
systemctl status ananicy.service --no-pager
systemctl cat ananicy.service
journalctl -b -u ananicy.service --no-pager
ps -eo pid,comm,ni,cls --sort=ni
find /etc/ananicy.d -maxdepth 3 -type f -name '*.rules' -print
```

The unit may be named `ananicy`, even though the executable/package is C++.
This repo does not explicitly select a custom `rulesProvider`; inspect the pinned
module's default and generated rule tree. Check options before customizing:

```bash
nix eval --json .#nixosConfigurations.nixos.options.services.ananicy --apply builtins.attrNames
nix eval --raw .#nixosConfigurations.nixos.config.services.ananicy.rulesProvider.outPath
```

For a declarative local ruleset, create `rules/ananicy/local.rules` with one JSON
rule per line, for example a noncritical compiler background job:

```json
{"name":"gcc","nice":10,"sched":"batch","ioclass":"idle"}
```

After reviewing the installed rules and process matching, set an explicit local
provider package in the host goodies module (which already receives `pkgs`).
The package must contain the full chosen ruleset under `etc/ananicy.d`:

```nix
services.ananicy.rulesProvider = pkgs.runCommand "local-ananicy-rules" {} ''
  mkdir -p "$out/etc/ananicy.d"
  cp -r ${../../rules/ananicy}/. "$out/etc/ananicy.d/"
'';
```

This example **replaces** the selected provider; retain needed upstream rule files
in that directory deliberately if required. Confirm the pinned module's directory
contract using its option declaration before building. Do not edit a Nix-store
symlink in `/etc/ananicy.d` or blindly combine overlapping providers. Stage the
rules, build/test, inspect the generated files, then restart the actual unit if
activation has not done so. Do not copy privileged scheduling values without
checking their effect. The local example is optional; no new local rules are
activated by this audit.

GameMode renice is disabled to reduce competition over process nice values.
Other scheduling/I/O policies can still overlap. Inspect a game process's real
`NI`, scheduling class and I/O priority (`ionice -p PID`) while running it.

## GameMode

GameMode is enabled through native NixOS integration. Steam launch options use
`gamemoderun %command%`; hybrid offload uses
`nvidia-offload gamemoderun %command%`. `%command%` belongs to Steam. For an
independent application use its executable, such as `gamemoderun your-game`.
See the [gaming guide](GAMING_AND_GRAPHICS.md) for complete GPU coverage.

```bash
gamemoded -t
# While a requesting game is running:
gamemoded -s
journalctl --user -b -u gamemoded.service --no-pager
```

The test briefly exercises optimizations. No game benchmark or hardware GameMode
test was performed in this workspace.

## Storage: different tools do different jobs

| Feature | Configured behavior | Verify / limitation |
| --- | --- | --- |
| NVMe scheduler | `hardware.block.scheduler."nvme[0-9]*" = mkDefault "none"` | Inspect `/sys/block/nvme*/queue/scheduler`; bracketed entry is active; verify after device initialization/reboot |
| TRIM | `services.fstrim.enable = mkDefault true` | `systemctl list-timers --all`; `journalctl -u fstrim.service`; may trim other eligible mounted filesystems, not just NixOS |
| Compression | Btrfs mount `compress=zstd:3` | `findmnt -o TARGET,OPTIONS /`; applies to newly written extents, does not recompress all existing files |
| atime policy | `noatime` on four NixOS subvolumes | Reduces access-time updates; not an application throughput guarantee |
| Scrub | Monthly `/`, one whole Btrfs filesystem | `sudo btrfs scrub status /`; not a snapshot, not a backup, repair requires a good redundant copy |
| Optional maintenance | Native maintenance module supports SMART/fwupd/store optimisation | Those optional switches are currently off; don't claim automatic firmware updates or backups |

```bash
for disk in /sys/block/nvme*n*; do
  test ! -r "$disk/queue/scheduler" || cat "$disk/queue/scheduler"
done
findmnt -R / -o TARGET,SOURCE,FSTYPE,OPTIONS
systemctl list-timers --all | rg 'fstrim|btrfs'
sudo btrfs scrub status /
```

NVMe `none` means no additional multiqueue I/O scheduler, not no storage request
handling. Compare application latency under realistic load before preferring it
to another scheduler. Scrub covers the filesystem behind the selected root once,
including its subvolumes; the separate Garuda filesystem is not scrubbed by this
root job. fstrim's scope is broader, so do not describe it as excluding Garuda.

## ZRAM: compressed memory swap

The host enables compressed swap in RAM using Zstandard. Goodies supplies a 50%
`mkDefault`, but the normal-priority performance module supplies **90%** logical
swap capacity. That is not an immediate 90% physical RAM reservation. Actual RAM
use grows with compressed data and metadata; incompressible pages and CPU costs
limit its usefulness. The host also sets `vm.swappiness = 180`; compressed swap
can justify a different policy from disk swap, but the right value is workload
specific. No universal speedup or OOM prevention is promised.

```bash
nix eval --json .#nixosConfigurations.nixos.config.zramSwap.memoryPercent
nix eval --raw .#nixosConfigurations.nixos.config.zramSwap.algorithm
zramctl
swapon --show
free -h
sysctl vm.swappiness
cat /sys/block/zram0/mm_stat
```

Compare logical/data/compressed/total memory figures and memory pressure. Change
size through `hosts/nixos/performance-tuning.nix`, not manual writes to a live
swap device. Reboot for a clean resize/algorithm verification. Disabling only one
provider's custom flag can expose the other provider's fallback.

## Terminal appearance

Fish colors come from `garuda-terminal-goodies.nix`. Its prompt is **Starship**,
configured in `home/ankur/shell/starship.toml`; `shell/default.nix` enables it and
Fastfetch, and `fish.nix` supplies aliases/abbreviations. No active Fish plugin
manager is declared here. The system Fish login shell has its own host module.

Kitty is installed by HM's desktop package list and configured by
`hyprland/kitty.nix`. Its personal raw `kitty.conf` sets a Dracula-like palette,
opacity, font, shortcuts and cursor trail. The pastel palette in
`/etc/xdg/kitty/kitty.conf` is a system default and loses to conflicting user
settings. It is inaccurate to say Kitty is unmanaged by HM merely because
`programs.kitty.enable` is not used. See the
[desktop ownership guide](DESKTOP_AND_HOME_MANAGER.md) for the complete map.

References: [Ananicy C++](https://github.com/EvoXCX/ananicy-cpp),
[kernel ZRAM documentation](https://docs.kernel.org/admin-guide/blockdev/zram.html),
[Btrfs scrub](https://btrfs.readthedocs.io/en/latest/Scrub.html),
[power-profiles-daemon](https://gitlab.freedesktop.org/upower/power-profiles-daemon).
