# Shared account metadata only. Passwords are set interactively, never in Git.
{ config, lib, ... }: {
  options.my.user = {
    name = lib.mkOption {
      type = lib.types.addCheck (lib.types.strMatching "[a-z_][a-z0-9_-]{0,30}")
        (name: !(builtins.elem name [ "root" "nobody" "daemon" ]));
      default = "nixos";
      description = "Regular account name; choose per host rather than editing reusable modules.";
    };
    homeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/home/${config.my.user.name}";
    };
    description = lib.mkOption { type = lib.types.str; default = config.my.user.name; };
    git.name = lib.mkOption { type = lib.types.str; default = ""; };
    git.email = lib.mkOption { type = lib.types.str; default = ""; };
  };
}
