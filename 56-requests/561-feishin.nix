# ---
# id: "561-feishin"
# title: "Feishin Music Client (static, served by Caddy)"
# domain: 50
# folder: 56-requests
# status: active
# complexity: 1
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-45-navidrome
# provides: []
# requires: ["511-caddy", "553-navidrome"]
# ports: []
# upstream_docs: ["https://feishin.vercel.app/"]
# forum_links: []
# upstream_github: "https://github.com/jeffvli/feishin"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 56-requests/561-feishin.nix — Feishin Music Client
{ lib, pkgs, config, ... }:

let
  cfg = config.grapefruitMedia;
in
{
  # Feishin is a static client (no process, served by Caddy)
  # Just add to registry for ingress
  # (Handled in 51-ingress via registry)
}
