{ nixpkgs, source, hosts ? {}, profiles ? ../iso-configs }:
let
  publicSource = import ./iso-source.nix { lib = nixpkgs.lib; inherit source; };
  root = profiles;
  names = builtins.attrNames (nixpkgs.lib.filterAttrs (name: kind:
    kind == "regular" && nixpkgs.lib.hasSuffix ".nix" name
  ) (builtins.readDir root));
in
builtins.listToAttrs (map (filename: {
  name = "iso-" + nixpkgs.lib.removeSuffix ".nix" filename;
  value = let base = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs.isoSource = publicSource;
    modules = [ ../hosts/installer-iso/default.nix (root + "/${filename}") ];
  }; name = base.config.my.iso.sourceHost;
  in if name == null then base else if builtins.hasAttr name hosts then
    base.extendModules { modules = [ (import ./iso-host-template.nix { host = hosts.${name}; }) ]; }
    else throw "Unknown source host for ISO ${filename}: ${name}";
}) names)
