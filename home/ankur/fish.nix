{ ... }:

{
  programs.fish = {
    enable = true;

    shellAbbrs = {
      nrs = "nh os switch";
      nrb = "nh os build";
      nri = "nh os info";
    };

    shellAliases = {
      ll = "ls -lah";
    };

    interactiveShellInit = ''
      set -g fish_greeting
    '';
  };
}
