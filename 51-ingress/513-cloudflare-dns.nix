# ---
# id: "513-cloudflare-dns"
# title: "Cloudflare DNS for m7c5.de — No Proxy, Direct A-Records"
# domain: 50
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5130
# provides: [cloudflare-dns]
# requires: ["lib/registry"]
# ports: []
# upstream_docs: ["https://developers.cloudflare.com/dns/"]
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 51-ingress/513-cloudflare-dns.nix — Cloudflare DNS-only (no proxy)
{ lib, config, ... }:

let
  cfg = config.grapefruitMedia;
in
{
  # Cloudflare DNS: A/AAAA records point directly to WAN IP.
  # NO Cloudflare Proxy (orange cloud OFF) — we terminate TLS ourselves via Caddy.
  # Reason (ADR-5130): Cloudflare proxy would MITM TLS, breaking Caddy certs.

  # If using ACME/Let's Encrypt via Cloudflare DNS-01 challenge:
  security.acme = {
    acceptTerms = true;
    defaults = {
      dnsProvider = "cloudflare";
      credentialsFile = "/run/secrets/acme-cloudflare";  # systemd-credentials (ADR-5000)
    };
  };
}

# Gold-Standard (from ADR-5130):
# - Cloudflare DNS-01 challenge for certs, but NO proxy mode
# - Direct A-records → Caddy terminates TLS, no CF MITM
# - Credentials via systemd-credentials, never inline
