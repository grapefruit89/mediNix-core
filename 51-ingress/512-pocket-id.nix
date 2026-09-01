# ---
# id: "512-pocket-id"
# title: "Pocket ID — self-hosted OIDC IdP (native systemd)"
# domain: 50
# folder: 51-ingress
# status: active
# complexity: 4
# last_reviewed: 2026-09-01
# links:
# provides: ["pocket-id", "oidc"]
# requires: ["lib/service-factory", "lib/registry"]
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
#
# Contract with 511 (ADR-5110 / master plan 2026-09-01):
#   512 delivers: process + 127.0.0.1:port + optional ingress.vhosts entry.
#   511 delivers: TLS, templates, forward_auth, abort, .local, catch-all.
#   512 never writes services.caddy.* / Caddyfiles / ACME / DNS.
#
# Activation is explicit:
#   medinix.pocketId.enable = true
# Silent "forward-auth => start Pocket-ID" is gone. That collided with 511:
#   forward-auth is legal with an external auth proxy and Pocket-ID off.
# Local IdP path: pocketId.enable = true, forwardAuthUpstream empty
#   → 511 targets 127.0.0.1:<pocket-id-port>.
# External path: authProxyPresent + non-empty forwardAuthUpstream
#   → 512 stays off unless explicitly enabled.
#
# Exposure (browser vs. Caddy):
#   Caddy forward_auth talks to 127.0.0.1:5120. That needs no public vhost.
#   The login UI / OIDC redirect needs a hostname the *browser* can reach.
#   Default accessGroup=idp: HTTPS on the wildcard, no forward_auth (deadlock),
#   no CIDR abort. Override via medinix.ingress.vhosts."pocket-id".accessGroup:
#     "idp"      — WAN login (default, mkDefault)
#     "internal" — only trustedCidrs
#     "none"     — no vhost at all (forward_auth to loopback still works)
{ lib, pkgs, config, ... }:

let
  cfg = config.medinix;
  ing = cfg.ingress;
  svc = (import ../lib/registry.nix { inherit lib; }).services."pocket-id";

  externalAuth =
    (ing.authProxyPresent or false)
    && ((ing.auth.forwardAuthUpstream or "") != "");

  # No more implicit enable from auth.mode. Fail-closed, matches 511.
  active = cfg.pocketId.enable;

in {
  options.medinix.pocketId.exposure = lib.mkOption {
    type = lib.types.enum [ "idp" "internal" "none" ];
    default = "idp";
    description = ''
      How 511 publishes pocket-id when the service is enabled.

      - idp: public hostname, no forward_auth, no LAN-abort (browser login / OIDC).
      - internal: same hostname, abort outside ingress.trustedCidrs.
      - none: do not register an ingress vhost. Caddy may still reach
        127.0.0.1:<port> for forward_auth; users cannot open the IdP in a browser
        via {name}.{domain} or {name}.local.

      This option only writes medinix.ingress.vhosts."pocket-id".accessGroup
      as mkDefault. A host-level vhosts."pocket-id".accessGroup wins.
    '';
  };

  config = lib.mkIf (cfg.enable && active) {
    assertions = [
      {
        assertion = !(ing.auth.mode == "forward-auth" && externalAuth && cfg.pocketId.enable && ing.auth.forwardAuthUpstream == "127.0.0.1:${toString svc.port}");
        message = ''
          [mediNix] Pocket-ID is enabled and authProxyPresent points forwardAuthUpstream
          back at 127.0.0.1:${toString svc.port}. Pick one owner: local Pocket-ID
          (leave forwardAuthUpstream empty) or an external proxy (different upstream).
          Ref: ADR-5120 / 51-ingress contracts.authentication
        '';
      }
      {
        assertion = cfg.pocketId.exposure != "idp" || ing.enable;
        message = ''
          [mediNix] pocketId.exposure = "idp" publishes pocket-id.{domain} through 511,
          but ingress is disabled. Either enable medinix.ingress or set
          pocketId.exposure = "none" (loopback-only IdP).
        '';
      }
    ];

    services.pocket-id = {
      enable = true;
      settings = {
        HOST = "127.0.0.1";
        PORT = svc.port;
      };
      user  = "pocket-id";
      group = "media";  # shared GID 5000 per ADR-0000
    };

    # Hardening: network profile. Loopback-only — Caddy is the only WAN face.
    systemd.services.pocket-id = (import ../lib/service-factory.nix { inherit lib config pkgs; }) {
      name = "pocket-id";
      stateDir = svc.stateDir;
      profile = "network";
      hardeningOnly = true;
      extraConfig = {
        RestrictNetworkInterfaces = [ "lo" ];
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

    # Ingress contract only. 511 renders this; 512 does not touch Caddy.
    medinix.ingress.vhosts."pocket-id" = lib.mkIf (cfg.pocketId.exposure != "none") {
      accessGroup = lib.mkDefault cfg.pocketId.exposure;
    };
  };
}

# Gold-Standard (ADR-5120):
# - Pocket ID is the OIDC IdP; 511 decides if/when forward_auth points here
# - Port 5120 is loopback-only; no TLS/DNS/Caddyfile logic in this file
# - enable is explicit; forward-auth no longer implies a local IdP
# - vhost class idp = deadlock shield; exposure is a declared policy
# - GID 5000 (media) shared across mediNix; UID 5120 is isomorphic (512 × 10)
