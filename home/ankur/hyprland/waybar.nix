{ lib, pkgs, osConfig, ... }:
let
  c = osConfig.my.apps.desktop;
  internet = osConfig.my.apps.internet;
  util = osConfig.my.apps.utilities;
  active = c.enable && c.waybar.enable;
  base = builtins.fromJSON (builtins.readFile ./waybar/config.json);
  enabled = n:
    if n == "custom/updates" then false # Garuda Pacman update command has no NixOS equivalent.
    else if n == "custom/network_traffic" then c.networkTraffic.enable
    else if n == "temperature" then c.temperature.enable
    else if n == "backlight" then c.brightness.enable
    else if n == "custom/keyboard-layout" then util.enable && util.yad.enable
    else if n == "cpu" || n == "memory" then c.systemMonitor.enable && c.kitty.enable
    else if n == "pulseaudio" then c.audio.enable
    else if n == "network" then c.networkApplet.enable
    else if n == "idle_inhibitor" then c.hypridle.enable
    else if n == "custom/power" then c.powerMenu.enable
    else if n == "custom/launcher" then c.drawer.enable
    else true;
  bar = base // {
    "modules-left" = builtins.filter enabled base."modules-left";
    "modules-center" = builtins.filter enabled base."modules-center";
    "modules-right" = builtins.filter enabled base."modules-right";
    "custom/network_traffic" = base."custom/network_traffic" // {
      # Direct Bash invocation avoids /bin/bash assumptions on NixOS.
      exec = "${pkgs.bash}/bin/bash ${./waybar/scripts/network_traffic.sh}";
    };
    # Drop fixed Garuda hwmon paths. Enable module only after checking NixOS sensors.
    temperature = builtins.removeAttrs base.temperature [ "thermal-zone" "hwmon-path" ];
    "custom/updates" = { format = ""; };
    # Don't leave click targets pointing to removed application packages.
    clock = if util.enable && util.yad.enable then base.clock
      else builtins.removeAttrs base.clock [ "on-click" ];
    backlight = if util.enable && util.yad.enable then base.backlight
      else builtins.removeAttrs base.backlight [ "on-click" ];
    "pulseaudio" = if c.kitty.enable then base.pulseaudio
      else builtins.removeAttrs base.pulseaudio [ "on-click" ];
    "hyprland/window" = base."hyprland/window";
    "custom/keyboard-layout" = base."custom/keyboard-layout";
    "custom/launcher" = base."custom/launcher";
    "custom/power" = base."custom/power";
    "custom/weather" = if internet.enable && internet.curl.enable && util.enable && util.yad.enable
      then base."custom/weather" else builtins.removeAttrs base."custom/weather" [ "exec" "on-click" ];
  };
in {
  xdg.configFile = lib.mkIf active {
    "waybar/config".text = builtins.toJSON bar;
    "waybar/style.css".source = ./waybar/style.css;
    "waybar/launcher.png".source = ./waybar/launcher.png;
    "waybar/scripts" = {
      source = ./waybar/scripts;
      recursive = true;
    };
  };
}
