{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.powerBattery;
  powerHealth = pkgs.writeShellScriptBin "power-health" ''
    # Read-only system power diagnostic. No tuning, suspend or GPU mode changes.
    echo '=== Power & Battery (read-only) ==='
    echo
    echo '[Battery / AC adapters]'
    for p in /sys/class/power_supply/*; do
      [ -d "$p" ] || continue
      echo "Device: ''${p##*/}"
      for field in type status online capacity health charge_control_end_threshold; do
        if [ -r "$p/$field" ]; then
          printf '  %s: ' "$field"
          cat "$p/$field"
        fi
      done
    done
    echo
    echo '[CPU frequency policy]'
    for p in /sys/devices/system/cpu/cpufreq/policy*; do
      [ -d "$p" ] || continue
      echo "Policy: ''${p##*/}"
      for field in scaling_driver scaling_governor energy_performance_preference; do
        if [ -r "$p/$field" ]; then
          printf '  %s: ' "$field"
          cat "$p/$field"
        fi
      done
    done
    echo
    echo '[Existing power services]'
    for s in power-profiles-daemon.service tlp.service auto-cpufreq.service thermald.service upower.service; do
      printf '  %s: ' "$s"
      ${pkgs.systemd}/bin/systemctl is-active "$s" 2>/dev/null || true
    done
    echo
    echo '[NVIDIA state (only if the driver exposes it)]'
    if command -v nvidia-smi >/dev/null 2>&1; then
      nvidia-smi --query-gpu=name,power.draw --format=csv,noheader 2>/dev/null || \
        echo 'NVIDIA power details unavailable (may be runtime suspended).'
    else
      echo 'nvidia-smi not on PATH; original GPU settings remain unchanged.'
    fi
    echo
    echo 'No settings were modified.'
  '';
in
{
  options.my.system.powerBattery = {
    enable = lib.mkEnableOption "modular laptop power and battery diagnostics/tuning";
    diagnostics.enable = lib.mkEnableOption "read-only power-health command";
    tools.powertop.enable = lib.mkEnableOption "install the interactive PowerTOP analyzer";
    tools.acpi.enable = lib.mkEnableOption "install the acpi status command";
    services.upower.enable = lib.mkEnableOption "enable UPower battery information daemon";
    profiles.powerProfilesDaemon.enable = lib.mkEnableOption "enable power-profiles-daemon (do not mix with TLP)";
    profiles.tlp.enable = lib.mkEnableOption "enable TLP with upstream defaults (may override current tuning)";
    profiles.autoCpufreq.enable = lib.mkEnableOption "enable auto-cpufreq (exclusive with TLP/PPD)";
    tuning.powertopAutoTune.enable = lib.mkEnableOption "apply PowerTOP auto-tune at startup (can affect USB peripherals)";
    thermal.thermald.enable = lib.mkEnableOption "Intel-only thermald daemon (not recommended for this AMD laptop)";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # No generic NVIDIA runtime power-management knobs here: the RTX 5050
      # PRIME offload configuration stays under modules/hardware/nvidia-hybrid.nix.
      assertions = [
        {
          assertion = !(cfg.profiles.tlp.enable &&
                        (config.services.power-profiles-daemon.enable ||
                         config.services.auto-cpufreq.enable));
          message = "Power/Battery: TLP conflicts with power-profiles-daemon/auto-cpufreq. Disable the existing backend before enabling TLP.";
        }
        {
          assertion = !(cfg.profiles.autoCpufreq.enable &&
                        (config.services.tlp.enable || config.services.power-profiles-daemon.enable));
          message = "Power/Battery: auto-cpufreq conflicts with TLP/power-profiles-daemon.";
        }
        {
          assertion = !(cfg.profiles.powerProfilesDaemon.enable &&
                        (config.services.tlp.enable || config.services.auto-cpufreq.enable));
          message = "Power/Battery: power-profiles-daemon conflicts with TLP/auto-cpufreq.";
        }
        {
          assertion = !(cfg.tuning.powertopAutoTune.enable &&
                        (config.services.tlp.enable || config.services.auto-cpufreq.enable));
          message = "Power/Battery: do not combine automatic PowerTOP tuning with TLP or auto-cpufreq.";
        }
        {
          assertion = !cfg.thermal.thermald.enable || config.my.hardware.gpu.integratedVendor == "intel";
          message = "Power/Battery: thermald is meant for Intel; this laptop uses AMD. Leave thermal.thermald.enable = false.";
        }
      ];
      environment.systemPackages =
        lib.optional cfg.diagnostics.enable powerHealth
        ++ lib.optional cfg.tools.powertop.enable pkgs.powertop
        ++ lib.optional cfg.tools.acpi.enable pkgs.acpi;
    }
    (lib.mkIf cfg.services.upower.enable { services.upower.enable = true; })
    (lib.mkIf cfg.profiles.powerProfilesDaemon.enable { services.power-profiles-daemon.enable = true; })
    (lib.mkIf cfg.profiles.tlp.enable { services.tlp.enable = true; })
    (lib.mkIf cfg.profiles.autoCpufreq.enable { services.auto-cpufreq.enable = true; })
    (lib.mkIf cfg.tuning.powertopAutoTune.enable { powerManagement.powertop.enable = true; })
    (lib.mkIf cfg.thermal.thermald.enable { services.thermald.enable = true; })
  ]);
}
