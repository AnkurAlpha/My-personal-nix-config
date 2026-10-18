{ config, lib, pkgs, ... }:

{
  options.mySystem.development = {

    enable = lib.mkEnableOption "development tools";

    editor = lib.mkOption {
      type = lib.types.enum [ "vim" "neovim" ];
      default = "neovim";
      description = "Preferred text editor";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional development packages";
    };

  };

  config = lib.mkIf config.mySystem.development.enable {

    environment.systemPackages = with pkgs; [
      git
      wget
      cowsay

      (if config.mySystem.development.editor == "neovim"
       then neovim
       else vim)

    ] ++ config.mySystem.development.extraPackages;

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
