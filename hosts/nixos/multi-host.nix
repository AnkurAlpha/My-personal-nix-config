{ config, ... }: {
  my.system.multiHost = {
    enable = true;
    repoPath = "${config.my.user.homeDirectory}/nixos-config";
    garudaMount = "/mnt/garuda";
    tools.enable = true;
    tools.hosts.enable = true;
    tools.isoBuilder.enable = true;
    tools.templateHelp.enable = true;
    iso.outputDirectory = "${config.my.user.homeDirectory}/ISO";
  };
}
