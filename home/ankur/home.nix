{ pkgs, ... }:

{
  home.username = "ankur";
  home.homeDirectory = "/home/ankur";

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    bat
    gnupg
    pass
  ];

  programs.home-manager.enable = true;


  home.file.".config/nix-learning/welcome.txt".text = ''
    Hello Ankur!
    This file is managed by Home Manager.
    I can reproduce this file on another NixOS machine!
  '';

  # Personal Fish abbreviations
  imports = [
  ./fish.nix
  ./git.nix
  ./gpg.nix
  ./hyprland


];
}
