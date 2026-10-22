{ ... }: {
  # Networking stays managed by your EXISTING NetworkManager configuration.
  # Only diagnostic packages are on by default; no DNS, VPN, or port changes.
  my.system.networking = {
    enable = true;
    diagnostics.enable = true;              # net-health (read-only)
    tools.dns.enable = true;                # dig / nslookup
    tools.mtr.enable = true;                # route diagnostics
    tools.traceroute.enable = true;
    tools.iperf3.enable = true;             # client CLI only
    tools.ethtool.enable = true;
    tools.nmap.enable = false;
    tools.tcpdump.enable = false;
    vpn.wireguardTools.enable = false;
    vpn.openvpnPlugin.enable = false;       # may restart NetworkManager if enabled
    vpn.tailscale.enable = false;           # manual login needed if enabled
    dns.systemdResolved.enable = false;    # changes DNS backend; opt-in only
    discovery.avahi.enable = false;        # opt-in .local / mDNS UDP 5353
    firewall.enforce.enable = false;       # preserve existing firewall policy
  };
}
