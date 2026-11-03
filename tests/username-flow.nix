# Evaluate the existing desktop under a different account without activating it.
{ nixpkgs, laptop }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  config = (laptop.extendModules {
    modules = [ ({ lib, ... }: { my.user.name = lib.mkForce "alice"; }) ];
  }).config;
in
assert config.users.users.alice.isNormalUser;
assert !(config.users.users ? ankur);
assert config.home-manager.users.alice.home.username == "alice";
assert config.home-manager.users.alice.home.homeDirectory == "/home/alice";
assert config.programs.nh.flake == "/home/alice/nixos-config";
assert config.my.system.multiHost.repoPath == "/home/alice/nixos-config";
assert config.my.system.nixosUpdates.repoPath == "/home/alice/nixos-config";
assert config.home-manager.users.alice.programs.git.settings.user.name == config.my.user.git.name;
assert nixpkgs.lib.hasInfix "/home/alice/.config/waybar/launcher.png"
  config.home-manager.users.alice.xdg.configFile."waybar/style.css".text;
assert config.system.build.toplevel.drvPath != "";
pkgs.runCommand "dynamic-desktop-account-evaluation" {} ''
  echo 'The existing desktop account, Home Manager and helper paths follow the selected identity.' > "$out"
''
