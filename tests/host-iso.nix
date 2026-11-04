{ nixpkgs, source, laptop }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  lib = pkgs.lib;
  images = import ../lib/isos.nix {
    inherit nixpkgs source;
    hosts.nix-laptop = laptop;
    profiles = ./fixtures/iso-hosts;
  };
  c = images.iso-template.config;
in
assert lib.all (a: a.assertion) c.assertions;
assert c.my.iso.sourceHost == "nix-laptop";
assert c.users.users.alice.isNormalUser && !(c.users.users ? ankur);
assert c.users.users.alice.initialHashedPassword == "!";
assert c.users.users.alice.openssh.authorizedKeys.keys == [];
assert !c.services.openssh.enable;
assert !(builtins.hasAttr "/mnt/garuda" c.fileSystems);
assert c.fileSystems."/".fsType != "btrfs";
assert !c.hardware.nvidia.prime.offload.enable;
assert c.programs.hyprland.enable;
assert c.programs.steam.enable == laptop.config.programs.steam.enable;
assert c.boot.kernelPackages.kernel.version == laptop.config.boot.kernelPackages.kernel.version;
assert builtins.hasAttr "hypr/hyprland.lua" c.my.iso.desktopFiles;
assert lib.all (name: !(lib.hasPrefix "ssh/" name) && !(lib.hasPrefix "gnupg/" name))
  (builtins.attrNames c.my.iso.desktopFiles);
assert lib.any (p: (p.pname or "") == "kitty") c.environment.systemPackages;
assert c.system.build.isoImage.drvPath != "";
pkgs.runCommand "public-host-template-iso-evaluation" {} ''
  echo 'Selected-host desktop/apps export with fresh accounts and independent live mounts evaluated.' > "$out"
''
