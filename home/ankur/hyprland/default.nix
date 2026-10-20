{ lib, osConfig, ... }:
let
  c = osConfig.my.apps.desktop;
  a = osConfig.my.apps;
  active = name: c.enable && c.${name}.enable;
  enabledLua = ''
    -- Generated from hosts/ankur-laptop/applications.nix.
    -- Do not edit these booleans in Lua; edit the declarative host switches instead.
    local app_enabled = {
      networkApplet = ${if active "networkApplet" then "true" else "false"},
      waybar = ${if active "waybar" then "true" else "false"},
      mako = ${if active "mako" then "true" else "false"},
      clipboard = ${if active "clipboard" then "true" else "false"},
      wpaperd = ${if active "wpaperd" then "true" else "false"},
      hypridle = ${if c.enable && c.hypridle.enable && c.hypridleAutostart.enable then "true" else "false"},
      dock = ${if active "dock" then "true" else "false"},
      drawer = ${if active "drawer" then "true" else "false"},
      kitty = ${if active "kitty" then "true" else "false"},
      fish = ${if active "fish" then "true" else "false"},
      zellij = ${if active "zellij" then "true" else "false"},
      yazi = ${if active "yazi" then "true" else "false"},
      wofi = ${if active "wofi" then "true" else "false"},
      powerMenu = ${if active "powerMenu" then "true" else "false"},
      audio = ${if active "audio" then "true" else "false"},
      brightness = ${if active "brightness" then "true" else "false"},
      screenshots = ${if active "screenshots" then "true" else "false"},
      notifications = ${if active "notifications" then "true" else "false"},
      playerctl = ${if active "playerctl" then "true" else "false"},
      firefox = ${if a.internet.enable && a.internet.firefox.enable then "true" else "false"},
      vivaldi = ${if a.internet.enable && a.internet.vivaldi.enable then "true" else "false"},
      thunderbird = ${if a.internet.enable && a.internet.thunderbird.enable then "true" else "false"},
      githubDesktop = ${if a.internet.enable && a.internet.githubDesktop.enable then "true" else "false"},
      thunar = ${if a.utilities.enable && a.utilities.thunar.enable then "true" else "false"},
      geany = ${if a.utilities.enable && a.utilities.geany.enable then "true" else "false"},
      gparted = ${if a.utilities.enable && a.utilities.gparted.enable then "true" else "false"},
      inkscape = ${if a.multimedia.enable && a.multimedia.inkscape.enable then "true" else "false"},
      blender = ${if a.multimedia.enable && a.multimedia.blender.enable then "true" else "false"},
      meld = ${if a.utilities.enable && a.utilities.meld.enable then "true" else "false"},
      joplin = ${if a.utilities.enable && a.utilities.joplin.enable then "true" else "false"},
      galculator = ${if a.utilities.enable && a.utilities.galculator.enable then "true" else "false"},
      emote = ${if a.utilities.enable && a.utilities.emote.enable then "true" else "false"},
    }
  '';
in {
  imports = [
    ./kitty.nix
    ./wofi.nix
    ./mako.nix
    ./hyprlock.nix
    ./hypridle.nix
    ./waybar.nix
    ./drawer.nix
  ];
  # The compositor itself remains enabled even if the desktop app group is off.
  xdg.configFile."hypr/hyprland.lua".text = enabledLua + builtins.readFile ./hyprland.lua;
  xdg.configFile."wpaperd/config.toml" = lib.mkIf (active "wpaperd") {
    source = ./wpaperd/config.toml;
  };
  xdg.configFile."nwg-dock-hyprland/style.css" = lib.mkIf (active "dock") {
    source = ./dock/style.css;
  };
}
