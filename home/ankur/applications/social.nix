# Social applications controlled by hosts/ankur-laptop/social.nix.
{ lib, pkgs, osConfig, ... }:
let
  cfg = osConfig.my.apps.social;
in
{
  home.packages =
    (lib.optionals (cfg.enable && cfg.discord.enable) [ pkgs.discord ])
    ++ (lib.optionals (cfg.enable && cfg.telegram.enable) [ pkgs.telegram-desktop ])
    ++ (lib.optionals (cfg.enable && cfg.signal.enable) [ pkgs.signal-desktop ]);
}
