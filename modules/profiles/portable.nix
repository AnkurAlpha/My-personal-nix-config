{ config, lib, pkgs, ... }:
let cfg = config.my.profiles.portable;
in {
  options.my.profiles.portable = {
    enable = lib.mkEnableOption "minimal portable profile for NEW NixOS machines";
    packages.git.enable = lib.mkEnableOption "Git";
    packages.curl.enable = lib.mkEnableOption "curl";
    packages.vim.enable = lib.mkEnableOption "Vim";
    packages.htop.enable = lib.mkEnableOption "htop";
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      (lib.optional cfg.packages.git.enable pkgs.git)
      ++ (lib.optional cfg.packages.curl.enable pkgs.curl)
      ++ (lib.optional cfg.packages.vim.enable pkgs.vim)
      ++ (lib.optional cfg.packages.htop.enable pkgs.htop);
    # No boot, disk, NVIDIA, networking, user password, or Home Manager overrides.
  };
}
