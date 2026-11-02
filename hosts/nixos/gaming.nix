# Toggle gaming applications independently on this machine.
# Steam and GameMode require NixOS system modules.
{ config, lib, ... }:
let
  gaming = config.my.apps.gaming;
  selected = name: gaming.enable && gaming.${name}.enable;
in
{
  options.my.apps.gaming = {
    enable = lib.mkEnableOption "gaming applications and helpers";
    steam.enable = lib.mkEnableOption "Steam client";
    gamemode.enable = lib.mkEnableOption "Feral GameMode";
    mangohud.enable = lib.mkEnableOption "MangoHud overlay";
    nvidiaOffload.enable = lib.mkEnableOption "NVIDIA offload helper (uses existing GPU module)";
  };

  config = {
    my.apps.gaming = {
      enable = true;
      steam.enable = true;
      gamemode.enable = true;
      mangohud.enable = true;
      nvidiaOffload.enable = true;
    };

    # Steam sets up its own runtime and hardware integration.
    programs.steam.enable = selected "steam";
    programs.gamemode.enable = selected "gamemode";

    # Steam is unfree. The existing GPU/Social settings remain unchanged.
    nixpkgs.config.allowUnfree = lib.mkDefault true;
  };
}
