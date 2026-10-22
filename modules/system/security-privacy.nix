{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.securityPrivacy;
in
{
  # Everything is opt-in. Importing this module adds no packages or services.
  # USBGuard is intentionally excluded entirely.
  options.my.system.securityPrivacy = {
    enable = lib.mkEnableOption "optional security and privacy tools";

    apparmor.enable = lib.mkEnableOption "AppArmor mandatory access control";
    fail2ban.enable = lib.mkEnableOption "Fail2ban intrusion prevention";
    auditd.enable = lib.mkEnableOption "Linux audit subsystem and audit daemon";
    firejail.enable = lib.mkEnableOption "Firejail application sandbox tool";
    gnupgAgent.enable = lib.mkEnableOption "system GnuPG agent integration";
    secretsTools.enable = lib.mkEnableOption "age and sops command-line secret tools";
    sshHardening.enable = lib.mkEnableOption "harden SSH server authentication (does NOT enable SSH)";
    firewallEnforce.enable = lib.mkEnableOption "explicitly enable the NixOS firewall";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf cfg.apparmor.enable {
      security.apparmor.enable = true;
    })
    (lib.mkIf cfg.fail2ban.enable {
      services.fail2ban.enable = true;
    })
    (lib.mkIf cfg.auditd.enable {
      security.audit.enable = true;
      security.auditd.enable = true;
    })
    (lib.mkIf cfg.firejail.enable {
      programs.firejail.enable = true;
    })
    (lib.mkIf cfg.gnupgAgent.enable {
      programs.gnupg.agent.enable = true;
    })
    (lib.mkIf cfg.secretsTools.enable {
      environment.systemPackages = [ pkgs.age pkgs.sops ];
    })
    (lib.mkIf cfg.sshHardening.enable {
      # Does not enable the SSH service; affects it only if already enabled.
      services.openssh.settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    })
    (lib.mkIf cfg.firewallEnforce.enable {
      networking.firewall.enable = true;
    })
  ]);
}
