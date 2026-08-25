# ---
# id: "512-pocket-id"
# title: "Pocket ID — self-hosted OIDC IdP (native systemd)"
# domain: 50
# folder: 51-ingress
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links: 
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
# adr: ADR-5120
# ---

# 51-ingress/512-pocket-id.nix — Pocket ID OIDC IdP
# ADR-5120: Pocket ID = OIDC Provider (512, Port 5120, UID 5120).
# Active if cfg.pocketId.enable OR ingress.auth.mode=forward-auth.
# GID 5000 (media) for library access. No direct WAN exposure:
# Caddy does forward_auth to 127.0.0.1:5120.
{ lib, pkgs, config, ... }:

let
  cfg = config.medinix;
  svc = (import ../lib/registry.nix { inherit lib; }).services."pocket-id";
  active = cfg.pocketId.enable || cfg.ingress.auth.mode == "forward-auth";
in
lib.mkIf (cfg.enable && active) {

  services.pocket-id = {
    enable = true;
    settings = {
      HOST = "127.0.0.1";
      PORT = svc.port;
    };
    user  = "pocket-id";
    group = "media";  # shared GID 5000 per ADR-0000
  };

  # Hardening: network profile (CAP_NET_BIND_SERVICE for 5120, PrivateDevices=true)
  systemd.services.pocket-id = (import ../lib/service-factory.nix { inherit lib config pkgs; }) {
    name = "pocket-id";
    stateDir = svc.stateDir;
    profile = "network";
    hardeningOnly = true;
    extraConfig = {
      RestrictNetworkInterfaces = [ "lo" ];  # LAN only, Caddy proxies WAN
      ReadWritePaths = [ svc.stateDir ];
    };
  };

  users.users.pocket-id = {
    uid = svc.uid;
    group = "media";
    isSystemUser = true;
    home = svc.stateDir;
    createHome = true;
  };

  # Caddy forward_auth upstream points to Pocket ID (if ingress is active)
  # (Configuration in 511-caddy.nix: ing.auth.forwardAuthUpstream)

  medinix.ingress.vhosts."pocket-id" = { accessGroup = "idp"; };
}

# Gold-Standard (ADR-5120):
# - Pocket ID is OIDC IdP, Caddy does forward_auth to it
# - Never expose 5120 directly; Caddy terminates TLS + forwards
# - GID 5000 (media) shared across mediNix services for library access
# - UID 5120 is isomorphic (512 × 10)

