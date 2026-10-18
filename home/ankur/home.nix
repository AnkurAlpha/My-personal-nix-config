{ pkgs, ... }:

{
  home.username = "ankur";
  home.homeDirectory = "/home/ankur";

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    bat
  ];

  programs.home-manager.enable = true;


  home.file.".config/nix-learning/welcome.txt".text = ''
    Hello Ankur!
    This file is managed by Home Manager.
    I can reproduce this file on another NixOS machine!
  '';
  # Personal Fish abbreviations
  programs.fish = {
    enable = true;
  
    shellAbbrs = {
      nrs = "nh os switch";
      nrb = "nh os build";
      nri = "nh os info";
    };
  
    shellAliases = {
      ll = "ls -lah";
    };
  
    interactiveShellInit = ''
      set -g fish_greeting
    '';
  };
}
