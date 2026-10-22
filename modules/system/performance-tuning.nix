{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.performanceTuning;
  perfHealth = pkgs.writeShellScriptBin "perf-health" ''
    #!/usr/bin/env bash
    # Read-only report. Never modifies power, CPU, GPU, RAM or block settings.
    printf '=== Performance health (read-only) ===\n'
    printf '\n[Kernel]\n'
    ${pkgs.coreutils}/bin/uname -r

    printf '\n[CPU governors]\n'
    for p in /sys/devices/system/cpu/cpufreq/policy*; do
      [ -d "$p" ] || continue
      printf '%s: ' "''${p##*/}"
      if [ -r "$p/scaling_governor" ]; then
        ${pkgs.coreutils}/bin/cat "$p/scaling_governor"
      else
        printf 'not available\n'
      fi
    done

    printf '\n[Memory and swap]\n'
    ${pkgs.gnugrep}/bin/grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo || true
    for key in swappiness vfs_cache_pressure; do
      if [ -r "/proc/sys/vm/$key" ]; then
        printf '%s: ' "$key"
        ${pkgs.coreutils}/bin/cat "/proc/sys/vm/$key"
      fi
    done

    printf '\n[Block I/O schedulers]\n'
    for p in /sys/block/nvme*n* /sys/block/sd*; do
      [ -r "$p/queue/scheduler" ] || continue
      printf '%s: ' "''${p##*/}"
      ${pkgs.coreutils}/bin/cat "$p/queue/scheduler"
    done

    printf '\n[NVIDIA diagnostics if available]\n'
    if command -v nvidia-smi >/dev/null 2>&1; then
      nvidia-smi --query-gpu=name,power.draw,temperature.gpu --format=csv,noheader 2>/dev/null || \
        printf 'NVIDIA status unavailable (possibly runtime suspended).\n'
    else
      printf 'nvidia-smi is not on PATH. No GPU settings were changed.\n'
    fi
    printf '\nRead-only report complete.\n'
  '';
in
{
  options.my.system.performanceTuning = {
    enable = lib.mkEnableOption "optional, conservatively disabled system performance features";

    diagnostics.enable = lib.mkEnableOption "install read-only perf-health diagnostics";

    cpu = {
      performanceGovernor.enable = lib.mkEnableOption "force performance CPU governor; increases heat/power use";
      irqbalance.enable = lib.mkEnableOption "balance hardware interrupts with irqbalance";
    };

    memory = {
      zram.enable = lib.mkEnableOption "enable compressed RAM swap";
      zramPercent = lib.mkOption {
        type = lib.types.ints.between 1 100;
        default = 25;
        description = "ZRAM maximum uncompressed memory size as percent of RAM when enabled.";
      };
      lowSwappiness.enable = lib.mkEnableOption "set vm.swappiness to 10";
      cachePressure.enable = lib.mkEnableOption "set vm.vfs_cache_pressure to 50";
      earlyoom.enable = lib.mkEnableOption "enable EarlyOOM process killer (can terminate processes)";
    };

    storage.nvmeSchedulerNone.enable = lib.mkEnableOption "opt-in NVMe scheduler override to none (may not help)";

    tools = {
      hyperfine.enable = lib.mkEnableOption "install the hyperfine benchmark CLI";
      sysstat.enable = lib.mkEnableOption "install sysstat (iostat, mpstat)";
      stressNg.enable = lib.mkEnableOption "install stress-ng (deliberate system load tool)";
    };
  };

  # Every switch defaults to false, including the category switch. Therefore
  # this module contributes no configuration settings or packages by default.
  # In particular, it does not touch NVIDIA PRIME, AMDGPU, TLP, CPU policies,
  # kernel packages, GameMode, MangoHud, disk mounts, or power profiles.
  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf cfg.diagnostics.enable {
      environment.systemPackages = [ perfHealth ];
    })
    (lib.mkIf cfg.cpu.performanceGovernor.enable {
      powerManagement.cpuFreqGovernor = "performance";
    })
    (lib.mkIf cfg.cpu.irqbalance.enable {
      services.irqbalance.enable = true;
    })
    (lib.mkIf cfg.memory.zram.enable {
      zramSwap.enable = true;
      zramSwap.memoryPercent = cfg.memory.zramPercent;
    })
    (lib.mkIf cfg.memory.lowSwappiness.enable {
      boot.kernel.sysctl."vm.swappiness" = 10;
    })
    (lib.mkIf cfg.memory.cachePressure.enable {
      boot.kernel.sysctl."vm.vfs_cache_pressure" = 50;
    })
    (lib.mkIf cfg.memory.earlyoom.enable {
      assertions = [ {
        assertion = !config.systemd.oomd.enable;
        message = "Performance Tuning: disable the existing systemd-oomd service before enabling EarlyOOM to avoid competing memory killers.";
      } ];
      services.earlyoom.enable = true;
    })
    (lib.mkIf cfg.storage.nvmeSchedulerNone.enable {
      # Scoped to NVMe by NixOS's built-in block scheduler machinery.
      # Deliberately OFF by default; benchmark before using.
      hardware.block.scheduler."nvme[0-9]*" = "none";
    })
    (lib.mkIf cfg.tools.hyperfine.enable {
      environment.systemPackages = [ pkgs.hyperfine ];
    })
    (lib.mkIf cfg.tools.sysstat.enable {
      environment.systemPackages = [ pkgs.sysstat ];
    })
    (lib.mkIf cfg.tools.stressNg.enable {
      environment.systemPackages = [ pkgs.stress-ng ];
    })
  ]);
}
