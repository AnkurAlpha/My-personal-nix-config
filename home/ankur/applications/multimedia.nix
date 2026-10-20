{ lib, pkgs, osConfig, ... }:
let c = osConfig.my.apps.multimedia;
    add = on: xs: lib.optionals (c.enable && on) xs;
in {
  home.packages =
      add c.mpv.enable [ pkgs.mpv ]
    ++ add c.vlc.enable [ pkgs.vlc ]
    ++ add c.obs.enable [ pkgs.obs-studio ]
    ++ add c.blender.enable [ pkgs.blender ]
    ++ add c.inkscape.enable [ pkgs.inkscape ];
}
