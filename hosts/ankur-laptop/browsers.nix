# Switches for browsers available on this laptop.
{ lib, ... }:
{
  options.my.apps.browsers = {
    enable = lib.mkEnableOption "web browsers";
    firefox.enable = lib.mkEnableOption "Firefox";
    chromium.enable = lib.mkEnableOption "Chromium";
    vivaldi.enable = lib.mkEnableOption "Vivaldi";
  };

  config.my.apps.browsers = {
    enable = true;
    firefox.enable = false;
    chromium.enable = false;
    vivaldi.enable = true;
  };
}
