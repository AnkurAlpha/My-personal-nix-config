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

  # Fully declarative baseline; the old Garuda nvim/ directory is not in the archive.
  # Later we can replace this with a Nixvim module after inspecting its actual plugin config.
  programs.neovim = lib.mkIf (c.enable && c.neovim.enable) {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraLuaConfig = ''
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 4
      vim.opt.tabstop = 4
      vim.opt.termguicolors = true
    '';
  };
}
