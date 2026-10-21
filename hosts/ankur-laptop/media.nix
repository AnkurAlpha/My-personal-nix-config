# Enable/disable media apps independently for this laptop.
{ lib, ... }:
{
  options.my.apps.media = {
    enable = lib.mkEnableOption "media and creative applications";
    vlc.enable = lib.mkEnableOption "VLC media player";
    mpv.enable = lib.mkEnableOption "MPV media player";
    obs.enable = lib.mkEnableOption "OBS Studio recording/streaming";
    gimp.enable = lib.mkEnableOption "GIMP image editor";
    imagemagick.enable = lib.mkEnableOption "ImageMagick command-line image tools";
    ffmpeg.enable = lib.mkEnableOption "FFmpeg audio/video tools";
  };

  config.my.apps.media = {
    enable = true;
    vlc.enable = false;
    mpv.enable = true;
    obs.enable = true;
    gimp.enable = true;
    imagemagick.enable = true;
    ffmpeg.enable = true;
  };
}
