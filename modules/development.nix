{ config, lib, pkgs, ... }:

{
  options.mySystem.development.enable =
    lib.mkEnableOption "development tools"; # creating it as an option

  config = lib.mkIf config.mySystem.development.enable {
    environment.systemPackages = with pkgs; [
      git
      wget
      neovim
      cowsay
    ];
  };
}
# { pkgs, ... }:
# 
# {
#   environment.systemPackages = with pkgs; [
#     git
#     wget
#     neovim
#   ];
# }
