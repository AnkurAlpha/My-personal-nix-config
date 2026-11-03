{ config, ... }:

{
  imports = [
    ../../modules/identity.nix
    ../../modules/home/shared/default.nix
    ../../modules/home/garuda/default.nix
  ];

  home.username = config.my.user.name;
  home.homeDirectory = config.my.user.homeDirectory;
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
