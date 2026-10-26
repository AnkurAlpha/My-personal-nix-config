{ lib, osConfig, ... }:
let
  cfg = osConfig.my.system.sessionAppearance;
in
{
  config = lib.mkIf (cfg.enable && cfg.hyprsunset.enable) {
    # Home Manager owns both the config and the user systemd service.
    # UWSM's Wayland session target is used by the upstream HM module.
    services.hyprsunset = {
      enable = true;
      settings.profile = [
        { time = "7:30"; temperature = 4000; gamma = 1.0; }
        { time = "19:00"; temperature = 3000; gamma = 1.0; }
      ];
    };
  };
}
