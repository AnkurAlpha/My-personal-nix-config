# Declarative shell migration: Fish + Starship + Fastfetch.
# Keep ~/.config/fish/config.fish from Home Manager; do not source old Arch startup.
{ pkgs, lib, ... }:
{
  programs.fish = {
    enable = true;
    interactiveShellInit = lib.mkAfter ''
      # Fastfetch on interactive Fish startup only (not fish -c or scripts).
      if status is-interactive; and command -sq fastfetch
        fastfetch
      end
    '';
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    # Imported declaratively from the Garuda starship.toml.
    settings = builtins.fromTOML (builtins.readFile ./starship.toml);
  };

  # Avoid collisions with programs.fastfetch.settings by managing its directory.
  home.packages = [ pkgs.fastfetch ];
  xdg.configFile."fastfetch".source = ./fastfetch;
}
