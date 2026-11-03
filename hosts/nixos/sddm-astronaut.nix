{ pkgs, ... }:

let
  blackHole = pkgs.sddm-astronaut.override {
    embeddedTheme = "black_hole";
  };
in
{
  environment.systemPackages = [ blackHole ];

  services.displayManager.sddm.extraPackages = [
    blackHole
    pkgs.kdePackages.qtsvg
    pkgs.kdePackages.qtvirtualkeyboard
    pkgs.kdePackages.qtmultimedia
  ];
}
