# Optional system tuning. All NEW features are DISABLED by default.
# Power & Battery, hybrid AMD/NVIDIA, gaming, and kernel settings are unchanged.
{ ... }:
{
  my.system.performanceTuning = {
    enable = false;

    diagnostics.enable = false;

    cpu = {
      performanceGovernor.enable = false;
      irqbalance.enable = false;
    };

    memory = {
      zram.enable = false;
      zramPercent = 25; # inert until memory.zram.enable = true
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
}
