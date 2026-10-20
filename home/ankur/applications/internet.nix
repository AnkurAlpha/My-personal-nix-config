{ lib, pkgs, osConfig, ... }:
let c = osConfig.my.apps.internet;
    add = on: xs: lib.optionals (c.enable && on) xs;
in {
  home.packages =
      add c.firefox.enable [ pkgs.firefox ]
    ++ add c.vivaldi.enable [ pkgs.vivaldi ]
    ++ add c.thunderbird.enable [ pkgs.thunderbird ]
    ++ add c.githubDesktop.enable [ pkgs.github-desktop ]
    ++ add c.curl.enable [ pkgs.curl ]
    ++ add c.signal.enable [ pkgs.signal-desktop ];
}
