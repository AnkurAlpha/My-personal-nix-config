{ ... }:
{
  # Only edit this file to choose categories and applications.
  # Disabling a category overrides every per-app switch underneath it.
  my.apps = {
    development = {
      enable = true;
      neovim.enable = true;
      cpp.enable = true;
      clang.enable = false;
      python.enable = true;
      java.enable = false;
      node.enable = true;
      docker.enable = false;
      git.enable = true;
      buildTools.enable = true;
      wget.enable = true;
      cowsay.enable = false;
    };
    multimedia = {
      enable = true;
      mpv.enable = true;
      vlc.enable = false;
      obs.enable = true;
      blender.enable = false;
      inkscape.enable = false;
    };
    desktop = {
      enable = true;
      kitty.enable = true;
      fish.enable = true;
      zellij.enable = true;
      yazi.enable = true;
      waybar.enable = true;
      wofi.enable = true;
      mako.enable = true;
      wpaperd.enable = true;
      hyprlock.enable = true;
      hypridle.enable = true;
      hypridleAutostart.enable = true;
      dock.enable = true;
      drawer.enable = true;
      powerMenu.enable = true;
      networkApplet.enable = true;
      clipboard.enable = true;
      screenshots.enable = true;
      audio.enable = true;
      brightness.enable = true;
      systemMonitor.enable = true;
      notifications.enable = true;
      playerctl.enable = true;
      networkTraffic.enable = true;
      temperature.enable = true;
    };
    internet = {
      enable = true;
      firefox.enable = false;
      vivaldi.enable = true;
      thunderbird.enable = false;
      githubDesktop.enable = false;
      curl.enable = true;
      signal.enable = true;
    };
    utilities = {
      enable = true;
      thunar.enable = true;
      geany.enable = false;
      gparted.enable = true;
      meld.enable = true;
      joplin.enable = false;
      galculator.enable = true;
      emote.enable = true;
      yad.enable = true;
      swappy.enable = true;
      kate.enable = false;
    };
    security = {
      enable = true;
      gnupg.enable = true;
      pass.enable = true;
      gpgAgent.enable = true;
    };
    appearance = {
      enable = true;
      fonts.enable = true;
      theme.enable = true;
    };
  };
}
