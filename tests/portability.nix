# Evaluation fixtures only. These dummy disk paths must never be installed.
{ nixpkgs, home-manager }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  lib = pkgs.lib;
  variants = [ "none" "intel" "amd" "intel-nvidia" "amd-nvidia" "nvidia" ];
  make = graphics: desktop: (nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ../modules/profiles/machine.nix
      home-manager.nixosModules.home-manager
      {
        networking.hostName = "evaluation-only";
        system.stateVersion = "26.05";
        fileSystems."/" = { device = "/dev/disk/by-label/EVALUATION-ONLY"; fsType = "ext4"; };
        fileSystems."/boot" = { device = "/dev/disk/by-label/EVALUATION-EFI"; fsType = "vfat"; };
        boot.loader.systemd-boot.enable = true;
        my.machine = {
          username = "tester";
          inherit graphics desktop;
          integratedBusId = if lib.hasSuffix "-nvidia" graphics then "PCI:5@0:0:0" else "";
          nvidiaBusId = if lib.hasSuffix "-nvidia" graphics then "PCI:1@0:0:0" else "";
        };
      }
    ];
  }).config;
  valid = graphics: desktop:
    let
      c = make graphics desktop;
      hasNvidia = graphics == "nvidia" || lib.hasSuffix "-nvidia" graphics;
      hybrid = lib.hasSuffix "-nvidia" graphics;
    in
      lib.all (a: a.assertion) c.assertions
      && builtins.elem "nvidia" c.services.xserver.videoDrivers == hasNvidia
      && c.hardware.nvidia.prime.offload.enable == hybrid
      && c.hardware.nvidia.prime.sync.enable == false
      && !c.programs.steam.enable
      && !c.services.tlp.enable
      && !c.services.auto-cpufreq.enable
      && c.programs.hyprland.enable == (desktop == "hyprland")
      && c.system.build.toplevel.drvPath != "";
  success = lib.all (graphics: lib.all (desktop: valid graphics desktop) [ "minimal" "hyprland" ]) variants;
in
assert success;
pkgs.runCommand "new-host-portability-evaluation" {} ''
  echo 'Six GPU choices, two desktop profiles, assertions and toplevel derivation evaluation passed.' > "$out"
''
