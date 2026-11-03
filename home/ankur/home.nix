{ osConfig, ... }:

{
  home.username = osConfig.my.user.name;
  home.homeDirectory = osConfig.my.user.homeDirectory;

  home.stateVersion = "26.05";


  programs.home-manager.enable = true;


  home.file.".config/nix-learning/welcome.txt".text = ''
    Hello ${osConfig.my.user.name}!
    This file is managed by Home Manager.
    I can reproduce this file on another NixOS machine!
  '';

  # Personal Fish abbreviations
  imports = [
    ./hyprland/hyprsunset.nix
    ./storage-filesystems.nix
    ./qt-appearance.nix
    ./desktop-customization.nix
  ./fish.nix
  ./shell/default.nix
  ./git.nix
  ./gpg.nix
  ./hyprland
  ./zellij.nix
  ./fonts.nix
  ./theme.nix
  ./kde-cleanup.nix
  ./audio-bluetooth.nix
  ./applications
  ./applications/development/direnv.nix
  ./development-environments.nix
  ./trash-cleanup.nix
];
}
