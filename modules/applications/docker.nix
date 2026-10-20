{ lib, config, ... }:
let c = config.my.apps.development;
in {
  virtualisation.docker.enable = c.enable && c.docker.enable;
  users.users.ankur.extraGroups = lib.optionals (c.enable && c.docker.enable) [ "docker" ];
  # docker group grants root-equivalent privilege. Log out/in after changing membership.
}
