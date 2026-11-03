{ lib, config, ... }:
let c = config.my.apps.development;
in {
  imports = [ ../identity.nix ];
  config = lib.mkIf (c.enable && c.docker.enable) {
    virtualisation.docker.enable = true;
    users.users.${config.my.user.name}.extraGroups = [ "docker" ];
    # docker group grants root-equivalent privilege. Log out/in after changes.
  };
}
