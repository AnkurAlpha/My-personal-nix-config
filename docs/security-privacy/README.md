# Security & Privacy (configuration-only)

All features are disabled in `hosts/ankur-laptop/security-privacy.nix`.
Importing this module changes **no** security service, firewall rule, SSH setting,
package set or credentials. Existing NixOS defaults and settings remain in place.
USBGuard is intentionally excluded from this module.

To opt into a feature later, edit the host file, set the master `enable = true;`
and set the desired feature's switch to `true`, then build and switch:

```bash
nh os build ~/nixos-config -H ankur-laptop
nh os switch ~/nixos-config -H ankur-laptop
```

- `apparmor`: system MAC; may need reboot for full activation.
- `fail2ban`: intrusion prevention; useful primarily for enabled network services.
- `auditd`: enable kernel auditing and daemon; produces system logs.
- `firejail`: install sandbox launcher; does **not** wrap every program by default.
- `gnupgAgent`: GnuPG agent support, SSH agent support is NOT enabled.
- `secretsTools`: install `age` and `sops` binaries only; no secret files are created.
- `sshHardening`: disable SSH password/root logins if the SSH daemon is active;
  **configure working key-based SSH access first**, or you can lock yourself out.
  This switch does not start the SSH daemon.
- `firewallEnforce`: turn the firewall on explicitly; the switch being off
  preserves existing firewall settings, it does **not** disable the firewall.

`/mnt/garuda` is for read-only configuration references only.
