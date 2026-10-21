# Declarative shell migration: make Fish the login shell for ankur.
{ pkgs, ... }:
{
  programs.fish.enable = true;
  users.users.ankur.shell = pkgs.fish;
}
