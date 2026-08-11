# ---
# id: "523-nftables-hardening"
# title: "nftables Hardening (SSH-safe, no legacy iptables)"
# domain: 50
# folder: 52-security
# status: active
# complexity: 3
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-5043
# provides: []
# requires: []
# ports: [22, 2222, 80, 443]
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 52-security/523-nftables-hardening.nix — nftables (Simplified, SSH-safe)
{ lib, pkgs, config, ... }:

{
  networking.nftables.enable = true;

  # IMPORTANT: Port 22 (SSH) MUST be allowed, else assertion (595) fails!
  networking.firewall.allowedTCPPorts = [ 22 2222 80 443 ];  # SSH + Backup-SSH + Caddy

  # Media services only via Caddy (127.0.0.1), not directly from outside
  # Extra rules for LAN access (mDNS, etc.)
  networking.firewall.extraInputRules = ''
    # Allow mDNS for .local resolution
    udp dport 5353 accept

    # Allow ICMP (ping)
    ip protocol icmp accept
    icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, echo-request, echo-reply, nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
  '';
}
