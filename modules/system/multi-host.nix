{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.multiHost;
  fleet = pkgs.writeShellScriptBin "nix-fleet" ''
    export NIX_FLEET_REPO=${lib.escapeShellArg cfg.repoPath}
    export NIX_FLEET_GARUDA=${lib.escapeShellArg cfg.garudaMount}
    export NIX_FLEET_ISO_DIR=${lib.escapeShellArg cfg.iso.outputDirectory}
    export NIX_FLEET_HOSTS=${lib.boolToString cfg.tools.hosts.enable}
    export NIX_FLEET_ISO=${lib.boolToString cfg.tools.isoBuilder.enable}
    export NIX_FLEET_TEMPLATE=${lib.boolToString cfg.tools.templateHelp.enable}
    export PATH=${lib.escapeShellArg (lib.makeBinPath [ pkgs.nix pkgs.git pkgs.coreutils pkgs.findutils pkgs.util-linux pkgs.bash ])}:"$PATH"
    exec ${pkgs.bash}/bin/bash ${./nix-fleet.sh} "$@"
  '';
in
{
  options.my.system.multiHost = {
    enable = lib.mkEnableOption "safe multi-host tooling for this laptop";
    repoPath = lib.mkOption { type = lib.types.str; default = "/home/ankur/nixos-config"; };
    garudaMount = lib.mkOption { type = lib.types.str; default = "/mnt/garuda"; };
    tools.enable = lib.mkEnableOption "install the nix-fleet helper";
    tools.hosts.enable = lib.mkEnableOption "read-only list of flake NixOS hosts";
    tools.isoBuilder.enable = lib.mkEnableOption "manual installer ISO builds";
    tools.templateHelp.enable = lib.mkEnableOption "show the new-host template instructions";
    iso.outputDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/home/ankur/ISO";
      description = "Directory for ISO result links, not the Git checkout or Garuda mount.";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optional cfg.tools.enable fleet;
    # No bootloader, filesystem, service, partition, or GPU options here.
  };
}
