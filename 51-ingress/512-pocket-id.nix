# ---
# id: "512-pocket-id"
# title: "Pocket ID — self-hosted OIDC IdP (native systemd)"
# domain: 50
# folder: 51-ingress
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5120
# provides: ["pocket-id", "oidc"]
# requires: ["lib/registry", "lib/service-factory"]
# ports: [5120]
# upstream_docs: ["https://pocketid.org/docs/"]
# forum_links: []
# upstream_github: "https://github.com/pocket-id/pocket-id"
# nixpkgs_attr: "services.pocket-id"
# state_dir: "/var/lib/pocket-id-5120"
# uds_socket: false
# systemd_hardened: true
# ---

# 51-ingress/512-pocket-id.nix — Pocket ID OIDC IdP
# ADR-5120: Pocket ID = OIDC Provider (512, Port 5120, UID 5120).
# Aktiv wenn cfg.pocketId.enable ODER ingress.auth.mode=forward-auth.
# GID 5000 (media) für Bibliotheks-Zugriff. Keine direkte WAN-Exposition:
# Caddy macht forward_auth zu 127.0.0.1:5120.
{ lib, pkgs, config, ... }:

let
  cfg = config.grapefruitMedia;
  svc = (import ../lib/registry.nix { inherit lib; }).services."pocket-id";
  active = cfg.pocketId.enable || cfg.ingress.auth.mode == "forward-auth";
in
lib.mkIf (cfg.enable && active) {

  services.pocket-id = {
    enable = true;
    user  = "pocket-id";
    group = "media";  # shared GID 5000 per ADR-0000
  };

  # Hardening: network-Profil (CAP_NET_BIND_SERVICE für 5120, PrivateDevices=true)
  systemd.services.pocket-id = {
    serviceConfig = lib.mkMerge [
      (import ../lib/hardening-profiles.nix { inherit lib; }).network
      {
        User  = "pocket-id";
        Group = "media";
        RestrictNetworkInterfaces = [ "lo" ];  # LAN only, Caddy proxies WAN
        ReadWritePaths = [ "/var/lib/pocket-id-5120" ];
      }
    ];
  };

  users.users.pocket-id = {
    uid = svc.uid;
    group = "media";
    isSystemUser = true;
    home = "/var/lib/pocket-id-5120";
    createHome = true;
  };

  # Caddy forward_auth upstream zeigt auf Pocket ID (wenn ingress aktiv)
  # (Konfiguration in 511-caddy.nix: ing.auth.forwardAuthUpstream)
}

# Gold-Standard (ADR-5120):
# - Pocket ID ist OIDC IdP, Caddy macht forward_auth zu ihr
# - Nie 5120 direkt exponieren; Caddy terminiert TLS + forwards
# - GID 5000 (media) shared across mediNix services für library access
# - UID 5120 isomorph (512 × 10)
