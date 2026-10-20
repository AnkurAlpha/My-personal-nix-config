{ lib, pkgs, osConfig, ... }:

{
  config = lib.mkIf (osConfig.my.apps.security.enable && osConfig.my.apps.security.gpgAgent.enable) {
  services.gpg-agent = {
    enable = true;

    # Use the graphical Qt pinentry program
    pinentry.package = pkgs.pinentry-qt;
    pinentry.program = "pinentry-qt";

    # Integrate with our Fish shell
    enableFishIntegration = true;
  };
};
}
