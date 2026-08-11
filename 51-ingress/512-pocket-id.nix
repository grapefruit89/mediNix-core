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
# provides: [pocket-id]
# requires: ["lib/registry", "lib/service-factory"]
# ports: [5120]
# upstream_docs: ["https://pocketid.org/docs/"]
# forum_links: []
# upstream_github: "https://github.com/pocket-id/pocket-id"
# nixpkgs_attr: "services.pocket-id"
# state_dir: "/var/lib/pocket-id"
# uds_socket: false
# systemd_hardened: true
# ---
# 51-ingress/512-pocket-id.nix — Pocket ID OIDC IdP
{ lib, pkgs, config, ... }:

let
  cfg = config.grapefruitMedia.pocketId;
  svc = (import ../lib/registry.nix { inherit lib; }).pocketId;
in
{
  services.pocket-id = {
    enable = true;
    # UID/GID from decimal framework: Port=Nummer*10, GID=5000
    user = "pocketid";
    group = "media";  # shared GID 5000 per ADR-0000
  };

  # Hardening baseline (ADR-5050)
  systemd.services.pocket-id = {
    serviceConfig = {
      ProtectSystem = "strict";
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictNetworkInterfaces = [ "lo" ];  # LAN only, Caddy proxies WAN
      ReadWritePaths = [ svc.stateDir ];
    };
  };

  # Allowed port for Pocket ID (via Caddy, not directly exposed)
  networking.firewall.allowedTCPPorts = [ svc.port ];
}

# Gold-Standard (from ADR-5120 / CLAUDE.md):
# - Pocket ID is OIDC IdP, Caddy does forward_auth to it
# - Never expose 5120 directly; Caddy terminates TLS + forwards
# - GID 5000 (media) shared across mediNix services for library access
