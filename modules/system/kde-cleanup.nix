{ config, lib, ... }:
let
  cfg = config.my.system.kdeCleanup;
in
{
  options.my.system.kdeCleanup = {
    enable = lib.mkEnableOption "safe KDE Plasma and KWallet cleanup for Hyprland";
    plasma.disable = lib.mkEnableOption "disable the Plasma 6 desktop (retain Hyprland and SDDM)";
    kwallet.disablePam = lib.mkEnableOption "disable KWallet PAM integration at login";
    kwallet.disableForUser = lib.mkEnableOption "turn off KWallet and KSecretD for ankur via Home Manager";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # The original host declaration of Plasma = true is deliberately left intact.
    # Turning this switch off again permits the host's original Plasma config.
    (lib.mkIf cfg.plasma.disable {
      services.desktopManager.plasma6.enable = lib.mkForce false;
    })
    (lib.mkIf cfg.kwallet.disablePam {
      security.pam.services.login.kwallet.enable = lib.mkForce false;
      security.pam.services.sddm.kwallet.enable = lib.mkForce false;
      security.pam.services.kde.kwallet.enable = lib.mkForce false;
    })
  ]);
}
