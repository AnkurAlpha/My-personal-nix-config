{ ... }: {
  my.system.multiHost = {
    enable = true;
    repoPath = "/home/ankur/nixos-config";
    garudaMount = "/mnt/garuda";
    tools.enable = true;
    tools.hosts.enable = true;
    tools.isoBuilder.enable = true;
    tools.templateHelp.enable = true;
    iso.outputDirectory = "/home/ankur/ISO";
  };
}
