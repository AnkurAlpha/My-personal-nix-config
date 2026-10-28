{ lib, pkgs, osConfig, ... }:
let
  c = osConfig.my.apps.academics;
  enabled = name: c.enable && c.${name}.enable;

  # MathWorks does not distribute the licensed MATLAB binaries through nixpkgs.
  # This is an FHS-compatible launcher for an independently installed copy.
  matlabFhs = pkgs.buildFHSEnv {
    name = "matlab-fhs";
    targetPkgs = p: with p; [
      zlib stdenv.cc.cc glib dbus
      fontconfig freetype libxkbcommon
      libx11 libxext libxi libxrender
      libxrandr libxtst libxfixes
      libglvnd alsa-lib libpulseaudio
    ];
    runScript = "bash";
  };
  matlabLauncher = pkgs.writeShellScriptBin "matlab" ''
    exec ${matlabFhs}/bin/matlab-fhs ${./academics/matlab-launch.sh} "$@"
  '';
in {
  home.packages =
       lib.optionals (enabled "rstudio") [ pkgs.rstudio ]
    ++ lib.optionals (enabled "matlab") [ matlabLauncher ];
}
