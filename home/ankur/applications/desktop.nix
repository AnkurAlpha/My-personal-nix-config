{ lib, pkgs, osConfig, ... }:
let c = osConfig.my.apps.desktop;
    add = on: xs: lib.optionals (c.enable && on) xs;
in {
  home.packages =
      add c.kitty.enable [ pkgs.kitty ]
    ++ add c.fish.enable [ pkgs.fish ]
    ++ add c.yazi.enable [ pkgs.yazi ]
    ++ add c.waybar.enable [ pkgs.waybar ]
    ++ add c.wofi.enable [ pkgs.wofi ]
    ++ add c.mako.enable [ pkgs.mako ]
    ++ add c.wpaperd.enable [ pkgs.wpaperd ]
    ++ add c.hyprlock.enable [ pkgs.hyprlock ]
    ++ add c.hypridle.enable [ pkgs.hypridle ]
    ++ add c.dock.enable [ pkgs.nwg-dock-hyprland ]
    ++ add c.drawer.enable [ pkgs.nwg-drawer ]
    ++ add c.powerMenu.enable [ pkgs.nwg-bar ]
    ++ add c.networkApplet.enable [ pkgs.networkmanagerapplet ]
    ++ add c.clipboard.enable [ pkgs.wl-clipboard pkgs.cliphist ]
    ++ add c.screenshots.enable [ pkgs.grimblast pkgs.grim pkgs.slurp pkgs.jq pkgs.hyprpicker pkgs.libnotify ]
    ++ add c.audio.enable [ pkgs.pamixer pkgs.pavucontrol pkgs.alsa-utils pkgs.pulseaudio pkgs.libnotify ]
    ++ add c.brightness.enable [ pkgs.brightnessctl ]
    ++ add c.systemMonitor.enable [ pkgs.htop ]
    ++ add c.notifications.enable [ pkgs.libnotify ]
    ++ add c.playerctl.enable [ pkgs.playerctl ];
}
