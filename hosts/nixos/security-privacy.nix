{ ... }:
{
  # Dormant features: NO package additions or service activation by this module.
  # To use an individual switch, set master enable=true AND that switch=true.
  # USBGuard is intentionally not offered.
  my.system.securityPrivacy = {
    enable = false;
    apparmor.enable = false;
    fail2ban.enable = false;
    auditd.enable = false;
    firejail.enable = false;
    gnupgAgent.enable = false;
    secretsTools.enable = false;
    sshHardening.enable = false;
    firewallEnforce.enable = false;
  };
}
