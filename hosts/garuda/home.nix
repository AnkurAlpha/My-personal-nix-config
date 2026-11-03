{ ... }:

{
  imports = [
    ../../modules/home/shared/default.nix
    ../../modules/home/garuda/default.nix
  ];

  home.username = "ankur";
  home.homeDirectory = "/home/ankur";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
