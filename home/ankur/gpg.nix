{ pkgs, ... }:

{
  services.gpg-agent = {
    enable = true;

    # Use the graphical Qt pinentry program
    pinentry.package = pkgs.pinentry-qt;
    pinentry.program = "pinentry-qt";

    # Integrate with our Fish shell
    enableFishIntegration = true;
  };
}
