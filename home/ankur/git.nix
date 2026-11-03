{ lib, osConfig, ... }:

{
  config = lib.mkIf (osConfig.my.apps.development.enable && osConfig.my.apps.development.git.enable) {
  programs.git = {
    enable = true;

    settings = {
      user =
        lib.optionalAttrs (osConfig.my.user.git.name != "") { name = osConfig.my.user.git.name; }
        // lib.optionalAttrs (osConfig.my.user.git.email != "") { email = osConfig.my.user.git.email; };

      safe.directory = "/etc/nixos";
    };
  };
};
}
