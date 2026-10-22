{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.networking;
  netHealth = pkgs.writeShellScriptBin "net-health" ''
    echo "=== NetworkManager service ==="
    ${pkgs.systemd}/bin/systemctl is-active NetworkManager.service || true
    echo
    echo "=== Device state (no saved connection secrets) ==="
    ${pkgs.networkmanager}/bin/nmcli --terse --fields DEVICE,TYPE,STATE device status || true
    echo
    echo "=== Interfaces ==="
    ${pkgs.iproute2}/bin/ip -brief address show || true
    echo
    echo "=== Default route ==="
    ${pkgs.iproute2}/bin/ip route show default || true
    echo
    echo "=== Resolver mode (no DNS changes made) ==="
    if ${pkgs.systemd}/bin/systemctl --quiet is-active systemd-resolved.service; then
      ${pkgs.systemd}/bin/resolvectl dns || true
    else
      ${pkgs.coreutils}/bin/readlink /etc/resolv.conf || true
    fi
    echo
    echo "=== Firewall service overview ==="
    ${pkgs.systemd}/bin/systemctl is-active firewall.service || true
    echo "This report makes no network configuration changes."
  '';
in
{
  options.my.system.networking = {
    enable = lib.mkEnableOption "toggleable networking utility and service module";
    diagnostics.enable = lib.mkEnableOption "read-only net-health overview";
    tools = {
      dns.enable = lib.mkEnableOption "dig and nslookup DNS diagnostics";
      mtr.enable = lib.mkEnableOption "MTR route diagnostics (some modes need elevated privileges)";
      traceroute.enable = lib.mkEnableOption "traceroute command";
      iperf3.enable = lib.mkEnableOption "iperf3 bandwidth tester (no server enabled)";
      ethtool.enable = lib.mkEnableOption "ethtool network interface diagnostics";
      nmap.enable = lib.mkEnableOption "nmap network scanner";
      tcpdump.enable = lib.mkEnableOption "tcpdump packet inspection (privileges required)";
    };
    vpn = {
      wireguardTools.enable = lib.mkEnableOption "WireGuard commands without starting a tunnel";
      openvpnPlugin.enable = lib.mkEnableOption "OpenVPN plugin for existing NetworkManager";
      tailscale.enable = lib.mkEnableOption "Tailscale client daemon (requires manual login)";
    };
    dns.systemdResolved.enable = lib.mkEnableOption "switch NetworkManager DNS handling to systemd-resolved";
    discovery.avahi.enable = lib.mkEnableOption "Avahi .local discovery (opens mDNS firewall port)";
    firewall.enforce.enable = lib.mkEnableOption "explicitly keep NixOS firewall enabled (no custom ports)";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [ {
        assertion = (!cfg.dns.systemdResolved.enable && !cfg.vpn.openvpnPlugin.enable)
          || config.networking.networkmanager.enable;
        message = "Networking DNS/OpenVPN switches require your existing NetworkManager service.";
      } ];
      environment.systemPackages =
        lib.optional cfg.diagnostics.enable netHealth
        ++ lib.optional cfg.tools.dns.enable (lib.hiPrio pkgs.dnsutils)
        ++ lib.optional cfg.tools.mtr.enable pkgs.mtr
        ++ lib.optional cfg.tools.traceroute.enable pkgs.traceroute
        ++ lib.optional cfg.tools.iperf3.enable pkgs.iperf3
        ++ lib.optional cfg.tools.ethtool.enable pkgs.ethtool
        ++ lib.optional cfg.tools.nmap.enable pkgs.nmap
        ++ lib.optional cfg.tools.tcpdump.enable pkgs.tcpdump
        ++ lib.optional cfg.vpn.wireguardTools.enable pkgs.wireguard-tools;
    }
    (lib.mkIf cfg.vpn.openvpnPlugin.enable {
      networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];
    })
    (lib.mkIf cfg.vpn.tailscale.enable {
      services.tailscale.enable = true;
      # Relays still work; do not implicitly open an inbound UDP port.
      services.tailscale.openFirewall = false;
    })
    (lib.mkIf cfg.dns.systemdResolved.enable {
      services.resolved.enable = true;
      networking.networkmanager.dns = "systemd-resolved";
    })
    (lib.mkIf cfg.discovery.avahi.enable {
      services.avahi.enable = true;
      services.avahi.nssmdns4 = true;
      services.avahi.openFirewall = true; # This is deliberate, opt-in only.
    })
    (lib.mkIf cfg.firewall.enforce.enable {
      networking.firewall.enable = true;
    })
  ]);
}
