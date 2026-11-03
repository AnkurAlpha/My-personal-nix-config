# Declarative shell migration: make Fish the login shell for the selected account.
{ config, pkgs, ... }:
{
  programs.fish.enable = true;
  users.users.${config.my.user.name}.shell = pkgs.fish;
}
