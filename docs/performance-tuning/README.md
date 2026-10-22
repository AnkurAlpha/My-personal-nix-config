# Performance Tuning (all new features disabled)

Files:
- `hosts/ankur-laptop/performance-tuning.nix` — individual switches
- `modules/system/performance-tuning.nix` — options and implementations

All feature switches **and** `my.system.performanceTuning.enable` are false.
Nothing is enabled or installed by this module until you explicitly opt in.
The existing AMD + NVIDIA PRIME offloading, kernel, GameMode, MangoHud,
power profiles, mounts and services are not changed by this module.

## Enable a feature

For example, enable read-only diagnostics:

```nix
my.system.performanceTuning.enable = true;
my.system.performanceTuning.diagnostics.enable = true;
```

After building and switching, run `perf-health`.

For ZRAM, additionally opt in to `memory.zram.enable` and optionally change
`memory.zramPercent` (defaults to 25). Any existing ZRAM definitions may
need reconciling first. For CPU governor tuning, inspect your Power & Battery
services to avoid fighting the existing policy; `performance` consumes more
power and may increase heat. Never assume a scheduler or sysctl tweak improves
performance: benchmark before/after, and change only one switch at a time.

`earlyoom` can terminate workloads under memory pressure. It requires disabling
the existing `systemd.oomd` service first (checked by an assertion). `stress-ng` puts
significant load on the system. NVMe scheduler overrides can harm rather than
improve latency on certain devices; benchmark them before opting in.

Do not disable CPU vulnerability mitigations or change NVIDIA PRIME/PCI bus IDs
for performance. This module intentionally provides no such switches.

To apply future changes:

```bash
nh os build ~/nixos-config -H ankur-laptop
nh os switch ~/nixos-config -H ankur-laptop
```

`/mnt/garuda` is only inspected by the installer; no files there are modified.
