{ lib, pkgs, ... }:
let
  settings = import ../../hosts/ankur-laptop/dev-environments.nix;
  helper = pkgs.writeShellApplication {
    name = "nix-dev";
    runtimeInputs = [ pkgs.nix ];
    text = ''
      export NIX_DEV_FLAKE=${lib.escapeShellArg settings.repoPath}
      exec ${pkgs.bash}/bin/bash ${../../modules/development/nix-dev.sh} "$@"
    '';
  };
in
{
  # Never overwrite the existing programs.direnv or nix-direnv options.
  home.packages = lib.optionals (settings.enable && settings.helper.enable) [ helper ];
}
