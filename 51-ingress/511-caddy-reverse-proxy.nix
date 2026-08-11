# ---
# id: "511-caddy-reverse-proxy"
# title: "Caddy Reverse Proxy + secure_headers Convention"
# domain: 50
# folder: 51-ingress
# status: draft
# complexity: 2
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-10-gateway.md
#   modules:
#     - path: Nix Files/modules/10-network.nix
# provides: []
# requires: []
# ports: [5110]
# upstream_docs: []
# forum_links: []
# upstream_github: ''
# nixpkgs_attr: 'services.caddy'
# state_dir: ''
# uds_socket: false
# systemd_hardened: false
# ---
# 51-ingress/511-caddy-reverse-proxy.nix — Caddy reverse proxy + secure headers
# Source: mediNix vector store (chat history), pattern-score 0.69
# VERIFY caddy adapter / reverse_proxy directive via Context7 before deploy
{ lib, config, ... }:

# Pattern: internal service port (NOT the external NZB/download port).
#   SABnzbd: internal 5410 (reverse_proxy sabnzbd:5410), external 58946 is NZB feed only.
#   Always terminate at Caddy, never expose service port directly.
#
# Caddyfile snippet (managed by 512-three-way-ingress):
#   sabnzbd.m7c5.de {
#     import secure_headers
#     import abort_unknown
#     reverse_proxy sabnzbd:5410
#   }
#
# secure_headers = baseline HSTS + X-Content-Type-Options etc.
# ⚠️ VERIFY: Caddy `reverse_proxy` + `import` directive syntax for your Caddy version.
#   Context7: "caddy reverse_proxy" / "caddy import snippet"
# ⚠️ VERIFY: service DNS name `sabnzbd` resolves via mediNix internal network
#   (systemd-resolved / container DNS) — not hardcoded IP.

let
  cfg = config.grapefruitMedia.caddy;
in
{
  options.grapefruitMedia.caddy = {
    enable = lib.mkEnableOption "Caddy reverse-proxy pattern";
    secureHeaders = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Inject secure_headers snippet on every site.";
    };
  };
  # No serviceConfig here — Caddy lives in 512-three-way-ingress.
  # This module documents the reverse_proxy + secure_headers convention.
}
