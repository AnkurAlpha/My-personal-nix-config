{ config, lib, pkgs, ... }:

{
  # Garuda-inspired switchable performance modes.
  services.power-profiles-daemon.enable = true;

  # Let the power-profile backend control CPU power behavior.
  # Overrides any older fixed "performance" governor.
  powerManagement.cpuFreqGovernor = lib.mkForce null;

  environment.systemPackages = [
    pkgs.power-profiles-daemon
  ];

  assertions = [
    {
      assertion =
        !config.services.tlp.enable
        && !config.services.auto-cpufreq.enable
        && !config.services.tuned.enable;
      message = "Garuda Extras: disable TLP, auto-cpufreq and tuned before enabling power-profiles-daemon.";
    }
  ];
}
