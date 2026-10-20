{ lib, pkgs, osConfig, ... }:
let c = osConfig.my.apps.security;
    add = on: xs: lib.optionals (c.enable && on) xs;
in {
  home.packages =
      add c.gnupg.enable [ pkgs.gnupg ]
    ++ add c.pass.enable [ pkgs.pass ];
}
