{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.nixosUpdates;
  updateCommand = pkgs.writeShellScriptBin "nix-update-safe" ''
    export NIX_UPDATE_REPO=${lib.escapeShellArg cfg.repoPath}
    export NIX_UPDATE_HOST=${lib.escapeShellArg cfg.host}
    export NIX_UPDATE_DIAGNOSTICS=${lib.boolToString cfg.diagnostics.enable}
    export NIX_UPDATE_SAFE_ALL=${lib.boolToString cfg.updates.safeAll.enable}
    export NIX_UPDATE_ALL=${lib.boolToString cfg.updates.allInputs.enable}
    export NIX_UPDATE_FIMLOOM=${lib.boolToString cfg.updates.allowFimloom.enable}
    export NIX_UPDATE_NIXPKGS_PIN=${lib.boolToString cfg.updates.allowNixpkgsPinChange.enable}
    export NIX_UPDATE_FLAKE_CHECK=${lib.boolToString cfg.validation.flakeCheck.enable}
    export NIX_UPDATE_CONFIRM=${lib.boolToString cfg.safety.confirmBeforeSwitch.enable}
    export NIX_UPDATE_COMMIT=${lib.boolToString cfg.git.autoCommit.enable}
    export PATH=${lib.escapeShellArg (lib.makeBinPath [ pkgs.git pkgs.nix pkgs.nh pkgs.jq pkgs.python3 pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.util-linux pkgs.bash ])}:"$PATH"
    exec ${pkgs.bash}/bin/bash ${./nix-update-safe.sh} "$@"
  '';
in
{
  options.my.system.nixosUpdates = {
    enable = lib.mkEnableOption "safe manual NixOS flake updates";
    repoPath = lib.mkOption { type = lib.types.str; default = "/home/ankur/nixos-config"; description = "Local Git flake path"; };
    host = lib.mkOption { type = lib.types.str; default = "ankur-laptop"; description = "NixOS flake host"; };
    cli.enable = lib.mkEnableOption "install nix-update-safe utility";
    diagnostics.enable = lib.mkEnableOption "read-only nix-update-safe status diagnostics";
    updates.safeAll.enable = lib.mkEnableOption "allow safe-all (excludes FIMLoom and pinned inputs)";
    updates.allInputs.enable = lib.mkEnableOption "allow 'all' update mode (requires FIMLoom permission)";
    updates.allowFimloom.enable = lib.mkEnableOption "permit updating FIMLoom explicitly";
    updates.allowNixpkgsPinChange.enable = lib.mkEnableOption "allow manually changing the exact Nixpkgs revision";
    validation.flakeCheck.enable = lib.mkEnableOption "run nix flake check after updating inputs (extra verification)";
    safety.confirmBeforeSwitch.enable = lib.mkEnableOption "require interactive confirmation before switch";
    git.autoCommit.enable = lib.mkEnableOption "commit updated lockfile after successful activation";
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = !cfg.updates.allInputs.enable || cfg.updates.allowFimloom.enable;
        message = "NixOS Updates: allInputs updates FIMLoom. Enable allowFimloom explicitly or use safeAll."; }
    ];
    environment.systemPackages = lib.optional cfg.cli.enable updateCommand;
    # Intentionally no system.autoUpgrade, garbage collection, or generation pruning.
  };
}
