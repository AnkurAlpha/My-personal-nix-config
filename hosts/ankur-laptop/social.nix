# Social app switches. Set any enable = false to remove that app.
{ lib, ... }:
{
  options.my.apps.social = {
    enable = lib.mkEnableOption "social communication applications";
    discord.enable = lib.mkEnableOption "Discord";
    telegram.enable = lib.mkEnableOption "Telegram Desktop";
    signal.enable = lib.mkEnableOption "Signal Desktop";
  };

  config = {
    my.apps.social = {
      enable = true;
      discord.enable = true;
      telegram.enable = true;
      signal.enable = true;
    };

    # Discord is not an open-source Nixpkgs package.
    nixpkgs.config.allowUnfree = lib.mkDefault true;
  };
}
