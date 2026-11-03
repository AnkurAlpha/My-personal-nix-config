{ nixpkgs, home-manager }:
let
  root = ../hosts;
  candidates = nixpkgs.lib.filterAttrs (name: kind:
    kind == "directory" && name != "nixos" && name != "installer-iso"
    && builtins.pathExists (root + "/${name}/configuration.nix")
  ) (builtins.readDir root);
in
nixpkgs.lib.mapAttrs (name: _: nixpkgs.lib.nixosSystem {
  # Generated hardware-configuration.nix supplies nixpkgs.hostPlatform.
  modules = [ (root + "/${name}/configuration.nix") home-manager.nixosModules.home-manager ];
}) candidates
