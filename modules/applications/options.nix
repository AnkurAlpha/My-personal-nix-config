{ lib, ... }:
let
  inherit (lib) mkEnableOption genAttrs;
  appOption = category: app: {
    enable = mkEnableOption "${category}.${app}";
  };
  category = name: apps: {
    enable = mkEnableOption "the ${name} group";
  } // genAttrs apps (app: appOption name app);
in {
  options.my.apps = {
    development = category "development" [ "neovim" "cpp" "clang" "python" "java" "node" "docker" "git" "buildTools" "wget" "cowsay" ];
    multimedia = category "multimedia" [ "mpv" "vlc" "obs" "blender" "inkscape" ];
    desktop = category "desktop" [ "kitty" "fish" "zellij" "yazi" "waybar" "wofi" "mako" "wpaperd" "hyprlock" "hypridle" "hypridleAutostart" "dock" "drawer" "powerMenu" "networkApplet" "clipboard" "screenshots" "audio" "brightness" "systemMonitor" "notifications" "playerctl" "networkTraffic" "temperature" ];
    internet = category "internet" [ "firefox" "vivaldi" "thunderbird" "githubDesktop" "curl" "signal" ];
    utilities = category "utilities" [ "thunar" "geany" "gparted" "meld" "joplin" "galculator" "emote" "yad" "swappy" "kate" ];
    systemTools = category "systemTools" [ "btop" "nvtop" "iotop" "powertop" "gdu" "duf" "dust" "ncdu" "filelight" "gnomeDisks" "smartmontools" "lmSensors" "lshw" "pciutils" "usbutils" "lsof" "nixTree" "nvd" "nixOutputMonitor" ];

    security = category "security" [ "gnupg" "pass" "gpgAgent" ];
    appearance = category "appearance" [ "fonts" "theme" ];
  };
}
