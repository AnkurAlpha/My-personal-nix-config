{ ... }: {
  # Each feature is active only when my.system.powerBattery.enable = true.
  # Existing NVIDIA PRIME, CPU governor, power daemon, suspend, PipeWire,
  # and other host configuration settings are preserved.
  my.system.powerBattery = {
    enable = true;
    diagnostics.enable = true;              # power-health (read-only)
    tools.powertop.enable = false;          # interactive diagnostics, optional
    tools.acpi.enable = false;              # optional acpi CLI
    services.upower.enable = false;         # preserve existing UPower behavior
    profiles.powerProfilesDaemon.enable = false; # preserve current profile daemon
    profiles.tlp.enable = false;            # optional TLP (NOT with PPD)
    profiles.autoCpufreq.enable = false;    # optional alternative; not with TLP/PPD
    tuning.powertopAutoTune.enable = false; # avoid USB autosuspend surprises
    thermal.thermald.enable = false;        # Intel-specific; AMD laptop
  };
}
