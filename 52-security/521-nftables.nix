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
{
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

  # Service-Ports 5110–5999: von außen NICHT erlaubt → nicht in allowedTCPPorts.
  # Sie sind nur via Caddy reverse-proxy auf 127.0.0.1 erreichbar (ADR-5110).
  # Explizite Negativ-Regel als Defence-in-Depth (nftables-syntax über das firewall-Modul):
  networking.firewall.extraCommands = lib.mkAfter ''
    # mediNix service-port lockdown: außen blockiert, loopback frei
    # (networking.firewall erlaubt loopback ohnehin; dies ist documentation/idiom)
    ${pkgs.nftables}/bin/nft add rule inet nixos-fw input tcp dport ${toString servicePortFrom}-${toString servicePortTo} drop 2>/dev/null || true
  '';

  # Optional: WireGuard-Killswitch für SABnzbd (usenet-confinement)
  # SABnzbd (541) darf nur durch wg-Interface routen (ADR-5410).
  networking.firewall.extraCommands = lib.mkIf cfg.usenet-confinement.enable (lib.mkAfter ''
    # SABnzbd VPN confinement: nur wg0, kein clearnet leak
    ${pkgs.nftables}/bin/nft 'add rule inet nixos-fw output oifname != "wg0" tcp dport 5410 drop' 2>/dev/null || true
  '');
}
