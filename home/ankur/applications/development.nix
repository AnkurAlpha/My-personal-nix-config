{ lib, pkgs, osConfig, ... }:
let
  c = osConfig.my.apps.development;
  add = on: xs: lib.optionals (c.enable && on) xs;
in {
  home.packages =
      add c.cpp.enable [ pkgs.gcc ]
    ++ add c.clang.enable [ pkgs.clang ]
    ++ add c.python.enable [ pkgs.python3 pkgs.uv ]
    ++ add c.java.enable [ pkgs.jdk21 ]
    ++ add c.node.enable [ pkgs.nodejs ]
    ++ add c.buildTools.enable [ pkgs.gnumake pkgs.cmake pkgs.pkg-config pkgs.ripgrep pkgs.fd ]
    ++ add c.wget.enable [ pkgs.wget ]
    ++ add c.cowsay.enable [ pkgs.cowsay ];

}
