# ---
# id: "514-acme"
# title: "Flake-managed ACME (Lego) with Cloudflare DNS-01 Challenge"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-09-01
# links:
# provides: ["acme", "tls", "certificates"]
# requires: []
# ports: []
# upstream_docs: ["https://wiki.nixos.org/wiki/ACME", "https://go-acme.github.io/lego/dns/cloudflare/"]
# forum_links: []
# upstream_github: "https://github.com/go-acme/lego"
# nixpkgs_attr: "security.acme"
# state_dir: "/var/lib/acme"
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5140
# ---
# 51-ingress/514-acme.nix — Flake-managed ACME Certificate Management
# ADR-5140: Certificates are NOT managed by Caddy. NixOS ACME / Lego only.
# DNS-01 via Cloudflare — no inbound 80/443 for issuance.
# Wildcard *.acmeHost; 511 only reads the resulting files.
#
# Credential contract (systemd only — no SOPS, no agenix, no SecretSpec, no
# plain tokenFile):
#   1. ingress.tls.acmeCredential
#   2. dns.ddns.cloudflareTokenCredential
#   3. dns.ddns.tokenCredential
# First non-null encrypted cred wins. Loaded with LoadCredentialEncrypted.
# Runtime path MUST include the unit suffix:
#   /run/credentials/acme-<host>.service/cf-acme-token
# File contents: KEY=value (CF_DNS_API_TOKEN=…).
#
# Reload contract: this module sets
#   security.acme.defaults.reloadServices = mkDefault [ "caddy.service" ]
# 511 overlays certs.<acmeHost>.reloadServices to caddy-media.service when
# standalone. 514 does not detect Caddy processes.
#
# This file is a config organ. Options live in default.nix.
# tls.mode = off does not disable acmeHost — 511 decides TLS enablement.
{ lib, config, ... }:

let
  cfg      = config.medinix;
  ing      = cfg.ingress;
  ddns     = cfg.dns.ddns;
  acmeHost = ing.tls.acmeHost;

  credPath =
    if      (ing.tls.acmeCredential or null)         != null then ing.tls.acmeCredential
    else if (ddns.cloudflareTokenCredential or null) != null then ddns.cloudflareTokenCredential
    else if (ddns.tokenCredential or null)           != null then ddns.tokenCredential
    else null;

  credRuntime = "/run/credentials/acme-${acmeHost}.service/cf-acme-token";

  contactMail =
    if (cfg.domain or null) != null then "admin@${cfg.domain}"
    else "admin@${acmeHost}";

in
lib.mkIf (cfg.enable && ing.enable && acmeHost != null) {

  users.groups.caddy = {};

  assertions = [
    {
      assertion = credPath != null;
      message = ''
        [mediNix] acmeHost is set but no systemd credential was provided.

        [AI/Admin Context]
        Reason: DNS-01 needs a Cloudflare API token. mediNix only accepts
        LoadCredentialEncrypted sources (no SOPS, no age module, no plain
        tokenFile in the Nix store / host path):
          1. ingress.tls.acmeCredential
          2. dns.ddns.cloudflareTokenCredential
          3. dns.ddns.tokenCredential
        The file must contain KEY=value, e.g. CF_DNS_API_TOKEN=…
        Ref: ADR-5140
      '';
    }
    {
      assertion = (ddns.tokenFile or null) == null || credPath != null;
      message = ''
        [mediNix] dns.ddns.tokenFile is ignored. Use a systemd credential.

        [AI/Admin Context]
        Plain token files are not part of the 51-ingress secret contract.
        Set acmeCredential or cloudflareTokenCredential instead.
        Ref: ADR-5140
      '';
    }
  ];

  security.acme = {
    acceptTerms = true;

    defaults = {
      email = contactMail;

      # Wildcard key must not sit in group media.
      # Global Caddy already uses group caddy; standalone caddy-media is
      # added to extraGroups = [ "caddy" ] in 511-caddy.nix.
      group = "caddy";

      # 511 overlays the unit that actually runs.
      reloadServices = lib.mkDefault [ "caddy.service" ];
    };

    certs.${acmeHost} = {
      domain           = acmeHost;
      extraDomainNames = [ "*.${acmeHost}" ];

      dnsProvider = "cloudflare";

      environment = {
        CLOUDFLARE_DNS_RESOLVERS = "1.1.1.1,1.0.0.1";
        CLOUDFLARE_POLLING_INTERVAL = "10";
        CLOUDFLARE_PROPAGATION_TIMEOUT = "120";
      };
    };
  };

  systemd.services."acme-${acmeHost}" = {
    serviceConfig = {
      LoadCredentialEncrypted = [ "cf-acme-token:${credPath}" ];
      EnvironmentFile = [ credRuntime ];
    };
  };
}

# Gold-Standard (ADR-5140):
# - Lego owns issuance; Caddy never starts ACME
# - systemd credentials only; tokenFile is rejected
# - group caddy even when services.caddy.enable is false
# - reload target is 511's contract, defaulted here to caddy.service
# - no HTTP-01, no port 80 for issuance
