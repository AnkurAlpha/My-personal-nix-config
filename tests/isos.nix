# Evaluates ISO derivations/settings; does not claim to boot an image.
{ nixpkgs, source }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  lib = pkgs.lib;
  check = desktop: username:
    let
      c = (nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs.isoSource = source;
        modules = [ ../hosts/installer-iso/default.nix {
          my.iso = { inherit desktop; liveUsername = username; };
        } ];
      }).config;
    in
      lib.all (a: a.assertion) c.assertions
      && c.users.users.${username}.isNormalUser
      && c.users.users.${username}.initialHashedPassword == "!"
      && c.users.users.nixos.enable == (username == "nixos")
      && !(c.users.users ? ankur)
      && c.users.users.root.initialHashedPassword == "!"
      && c.security.sudo.wheelNeedsPassword
      && !c.services.openssh.enable
      && c.services.getty.autologinUser == null
      && builtins.elem "live-user-setup.service" c.systemd.services."getty@".requires
      && c.programs.hyprland.enable == (desktop == "hyprland")
      && !c.hardware.nvidia.prime.offload.enable
      && c.system.build.isoImage.drvPath != "";
  success = lib.all (desktop: lib.all (username: check desktop username) [ "nixos" "alice" ]) [ "minimal" "hyprland" "plasma" "gnome" ];
in
assert success;
pkgs.runCommand "iso-accounts-evaluation" {} ''
  echo 'All supported live desktops and locked-before-setup dynamic accounts evaluated.' > "$out"
''
