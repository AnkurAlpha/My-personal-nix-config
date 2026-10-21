# MangoHud and a convenient offload command for Ankur's gaming apps.
# Controlled by my.apps.gaming in hosts/ankur-laptop/gaming.nix.
{ lib, pkgs, osConfig, ... }:
let
  gaming = osConfig.my.apps.gaming;
  selected = name: gaming.enable && gaming.${name}.enable;
  nvidiaGame = pkgs.writeShellScriptBin "game-on-nvidia" ''
    if [ "$#" -eq 0 ]; then
      echo 'Usage: game-on-nvidia <command> [args...]' >&2
      exit 2
    fi
    if ! command -v nvidia-offload >/dev/null 2>&1; then
      echo 'nvidia-offload is unavailable. Enable NVIDIA PRIME offload in your existing GPU module and reboot.' >&2
      exit 1
    fi
    exec nvidia-offload "$@"
  '';
in
{
  # Overlay is opt-in per game, NOT force-enabled for all desktop apps.
  programs.mangohud = {
    enable = selected "mangohud";
    enableSessionWide = false;
  };

  home.packages = lib.optionals (selected "nvidiaOffload") [ nvidiaGame ];
}
