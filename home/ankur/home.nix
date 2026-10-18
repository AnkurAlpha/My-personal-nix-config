{ pkgs, ... }:

{
  home.username = "ankur";
  home.homeDirectory = "/home/ankur";

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    bat
  ];

  programs.home-manager.enable = true;
}
