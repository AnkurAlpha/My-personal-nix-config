{ lib, pkgs, osConfig, ... }:
let
  c = osConfig.my.apps.multimedia;
in
{
  home.packages = lib.optional (c.enable && c.gwenview.enable) pkgs.kdePackages.gwenview;
}
