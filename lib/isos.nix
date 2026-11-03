{ nixpkgs, source }:
let
  root = ../iso-configs;
  names = builtins.attrNames (nixpkgs.lib.filterAttrs (name: kind:
    kind == "regular" && nixpkgs.lib.hasSuffix ".nix" name
  ) (builtins.readDir root));
in
builtins.listToAttrs (map (filename: {
  name = "iso-" + nixpkgs.lib.removeSuffix ".nix" filename;
  value = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs.isoSource = source;
    modules = [ ../hosts/installer-iso/default.nix (root + "/${filename}") ];
  };
}) names)
