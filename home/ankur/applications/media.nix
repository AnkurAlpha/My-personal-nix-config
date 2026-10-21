# Media packages, managed per-user through Home Manager.
# Switches are declared in hosts/ankur-laptop/media.nix.
{ lib, pkgs, osConfig, ... }:
let
  media = osConfig.my.apps.media;
  selected = name: media.enable && media.${name}.enable;
in
{
  home.packages =
    (lib.optionals (selected "vlc") [ pkgs.vlc ])
    ++ (lib.optionals (selected "mpv") [ pkgs.mpv ])
    ++ (lib.optionals (selected "obs") [ pkgs.obs-studio ])
    ++ (lib.optionals (selected "gimp") [ pkgs.gimp ])
    ++ (lib.optionals (selected "imagemagick") [ pkgs.imagemagick ])
    ++ (lib.optionals (selected "ffmpeg") [ pkgs.ffmpeg ]);
}
