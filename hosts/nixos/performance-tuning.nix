# Optional system tuning. This host explicitly enables ZRAM at 90%.
# Power & Battery, hybrid AMD/NVIDIA, gaming, and kernel settings are unchanged.
{ ... }:
{
  my.system.performanceTuning = {
    enable = true;

    diagnostics.enable = false;

    cpu = {
      performanceGovernor.enable = false;
      irqbalance.enable = false;
    };

    memory = {
      zram.enable = true;
      zramPercent = 90; # maximum logical swap size; physical use grows on demand
      lowSwappiness.enable = false;
      cachePressure.enable = false;
      earlyoom.enable = false;
    };

    storage.nvmeSchedulerNone.enable = false;

    tools = {
      hyperfine.enable = false;
      sysstat.enable = false;
      stressNg.enable = false;
    };
  };
  # Garuda-style compressed swap (leave other performance settings unchanged).
  boot.kernel.sysctl."vm.swappiness" = 180;
}
