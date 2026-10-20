{ lib, osConfig, ... }:

{
  config = lib.mkIf (osConfig.my.apps.development.enable && osConfig.my.apps.development.git.enable) {
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "AnkurAlpha";
        email = "comp2ankur@gmail.com";
      };

      safe.directory = "/etc/nixos";
    };
  };
};
}
