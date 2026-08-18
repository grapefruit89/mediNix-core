# ---
# id: "521-nftables"
# title: "nftables additive — block service ports from outside, open Caddy"
# domain: 52
# folder: 52-security
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5210
#   skill: nixos-context7-gate
# context7:
#   - query: "networking.nftables.tables example configuration"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "networking.nftables = true enables nftables-based firewall;
#       networking.firewall.allowedTCPPortRanges opens port ranges"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  # Service port range from isomorphism (ADR-0000 §4): 5110..5999
  servicePortFrom = 5110;
  servicePortTo   = 5999;
in
lib.mkIf cfg.enable {
  # Context7 verified: nftables-based firewall backend (not iptables)
  networking.nftables.enable = true;

  # ADDITIVE: we use the existing networking.firewall module.
  # Never define a custom table with type filter hook input —
  # this would replace the host firewall (ADR-5210: no iptables/nftables takeover).
  networking.firewall.enable = true;

  # Default: everything from outside is blocked (implicit deny in filter module).
  # We only explicitly open what Caddy (Ingress) needs.
  networking.firewall.allowedTCPPorts = lib.mkIf cfg.ingress.enable [
    80    # HTTP  (Caddy ACME http-01)
    443   # HTTPS (Caddy TLS)
  ];

}
