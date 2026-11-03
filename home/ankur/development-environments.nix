{ lib, pkgs, osConfig, ... }:
let
  settings = import ../../hosts/nixos/dev-environments.nix;
  repoPath = if settings.repoPath == null then "${osConfig.my.user.homeDirectory}/nixos-config" else settings.repoPath;
  helper = pkgs.writeShellApplication {
    name = "nix-dev";
    runtimeInputs = [ pkgs.nix ];
    text = ''
      export NIX_DEV_FLAKE=${lib.escapeShellArg repoPath}
      exec ${pkgs.bash}/bin/bash ${../../modules/development/nix-dev.sh} "$@"
    '';
  };
in
{
  # Never overwrite the existing programs.direnv or nix-direnv options.
  home.packages = lib.optionals (settings.enable && settings.helper.enable) [ helper ];
}
