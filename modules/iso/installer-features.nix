{ config, lib, pkgs, ... }:
let
  cfg = config.my.iso.features;
in
{
  options.my.iso.features = {
    enable = lib.mkEnableOption "additional tools for the stand-alone installer ISO";
    packages.git.enable = lib.mkEnableOption "Git for cloning host configuration";
    packages.neovim.enable = lib.mkEnableOption "Neovim text editor";
    packages.tmux.enable = lib.mkEnableOption "Tmux terminal multiplexer";
    packages.diskTools.enable = lib.mkEnableOption "Btrfs, ext4, and partition diagnostics";
    packages.ripgrep.enable = lib.mkEnableOption "Ripgrep search utility";
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      (lib.optional cfg.packages.git.enable pkgs.git)
      ++ (lib.optional cfg.packages.neovim.enable pkgs.neovim)
      ++ (lib.optional cfg.packages.tmux.enable pkgs.tmux)
      ++ (lib.optionals cfg.packages.diskTools.enable [ pkgs.btrfs-progs pkgs.e2fsprogs pkgs.parted ])
      ++ (lib.optional cfg.packages.ripgrep.enable pkgs.ripgrep);
    # This ISO contains no laptop-specific partitions, GPU settings, or personal keys.
  };
}
