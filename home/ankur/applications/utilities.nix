{ lib, pkgs, osConfig, ... }:
let c = osConfig.my.apps.utilities;
    add = on: xs: lib.optionals (c.enable && on) xs;
in {
  home.packages =
      add c.thunar.enable [ pkgs.thunar ]
    ++ add c.geany.enable [ pkgs.geany ]
    ++ add c.gparted.enable [ pkgs.gparted ]
    ++ add c.meld.enable [ pkgs.meld ]
    ++ add c.joplin.enable [ pkgs.joplin-desktop ]
    ++ add c.galculator.enable [ pkgs.galculator ]
    ++ add c.emote.enable [ pkgs.emote ]
    ++ add c.yad.enable [ pkgs.yad ]
    ++ add c.swappy.enable [ pkgs.swappy ]
    ++ add c.kate.enable [ pkgs.kdePackages.kate ];
}
