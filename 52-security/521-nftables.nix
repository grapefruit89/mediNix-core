# ---
# id: "521-nftables"
# title: "nftables additiv — blockiere Service-Ports von außen, öffne Caddy"
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
  # Service-Port-Bereich aus Isomorphie (ADR-0000 §4): 5110..5999
  servicePortFrom = 5110;
  servicePortTo   = 5999;
in
lib.mkIf cfg.enable {
  # Context7-verifiziert: nftables-basierter Firewall-Backend (nicht iptables)
  networking.nftables.enable = true;

  # ADDITIV: wir nutzen das bestehende networking.firewall-Modul.
  # Niemals eine eigene table mit type filter hook input definieren —
  # das würde die Host-Firewall ersetzen (ADR-5210: no iptables/nftables takeover).
  networking.firewall.enable = true;

  # Default: alles von außen blockiert (implicit deny im filter-Modul).
  # Wir öffnen nur explizit, was Caddy (Ingress) braucht.
  networking.firewall.allowedTCPPorts = lib.mkIf cfg.ingress.enable [
    80    # HTTP  (Caddy ACME http-01)
    443   # HTTPS (Caddy TLS)
  ];

}
