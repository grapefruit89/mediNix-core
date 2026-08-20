# ---
# id: "514-acme"
# title: "Flake-managed ACME (Lego) with Cloudflare DNS-01 Challenge"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-08-19
# links:
#   adr: ADR-5140
# provides: ["acme", "tls", "certificates"]
# requires: ["options.grapefruitMedia"]
# ports: []
# upstream_docs: ["https://nixos.wiki/wiki/ACME", "https://go-acme.github.io/lego/dns/cloudflare/"]
# nixpkgs_attr: "security.acme"
# state_dir: "/var/lib/acme"
# uds_socket: false
# systemd_hardened: true
# ---

# 51-ingress/514-acme.nix — Flake-managed ACME Certificate Management
# ADR-5140: Certificates are NOT managed by Caddy, but natively by NixOS (Lego).
# Uses DNS-01 challenge via Cloudflare API — no ports (80/443) need WAN exposure.
# Generates a wildcard certificate (*.domain.tld) which Caddy then consumes.
#
# Token priority (first non-null wins):
#   1. ing.tls.acmeCredential            — dedicated ACME .cred file (preferred)
#   2. dns.ddns.cloudflareTokenCredential — shared Cloudflare cred (DDNS reuse)
#   3. dns.ddns.tokenCredential          — legacy alias
#   4. dns.ddns.tokenFile                — plain file fallback (not TPM-sealed)
#
# For options 1-3, the credential is loaded via systemd LoadCredentialEncrypted
# and injected as EnvironmentFile. The runtime path MUST include the .service suffix:
#   /run/credentials/acme-<host>.service/cf-acme-token
{ lib, config, ... }:

let
  cfg      = config.grapefruitMedia;
  ing      = cfg.ingress;
  ddns     = cfg.dns.ddns;
  acmeHost = ing.tls.acmeHost;

  # First non-null encrypted credential path wins
  credPath =
    if      ing.tls.acmeCredential             != null then ing.tls.acmeCredential
    else if ddns.cloudflareTokenCredential     != null then ddns.cloudflareTokenCredential
    else if ddns.tokenCredential               != null then ddns.tokenCredential
    else null;

  # Plain file fallback — only used when no encrypted cred is available
  plainTokenFile =
    if credPath == null && ddns.tokenFile != null then ddns.tokenFile
    else null;

  # systemd credential runtime path — .service suffix is REQUIRED
  credRuntime = "/run/credentials/acme-${acmeHost}.service/cf-acme-token";

in
lib.mkIf (cfg.enable && ing.enable && acmeHost != null) {

  assertions = [
    {
      assertion = credPath != null || plainTokenFile != null;
      message = "ACME Host is set, but no Cloudflare token credential or plain file is provided. This would fail silently at runtime.";
    }
  ];

  security.acme = {
    acceptTerms = true;

    defaults = {
      # Let's Encrypt contact address (expiration warnings)
      email = "admin@${cfg.domain}";

      # P0.3: Wildcard key must NOT belong to the broad "media" group (blast radius).
      # Certificate group is limited to the Caddy process only.
      group = if config.services.caddy.enable
              then config.services.caddy.group
              else "caddy-media";

      # Reload Caddy after certificate renewal
      reloadServices =
        if config.services.caddy.enable
        then [ "caddy.service" ]
        else [ "caddy-media.service" ];
    };

    certs.${acmeHost} = {
      domain           = acmeHost;
      extraDomainNames = [ "*.${acmeHost}" ];

      # DNS-01 Challenge via Cloudflare
      dnsProvider = "cloudflare";

      # Plain file path — only set when no TPM-sealed credential is available.
      # When credPath != null, the EnvironmentFile override below takes precedence.
      credentialsFile = lib.mkIf (plainTokenFile != null) plainTokenFile;
    };
  };

  # Inject the TPM-sealed token via systemd LoadCredentialEncrypted.
  # This overrides the credentialsFile mechanism so the plain token never
  # touches the filesystem unencrypted.
  systemd.services."acme-${acmeHost}" = lib.mkIf (credPath != null) {
    serviceConfig = {
      LoadCredentialEncrypted = [ "cf-acme-token:${credPath}" ];
      # IMPORTANT: The credential file MUST contain KEY=value syntax (e.g. CF_DNS_API_TOKEN=your_token)
      # mkForce: override whatever security.acme set for EnvironmentFile
      EnvironmentFile = lib.mkForce [ credRuntime ];
    };
  };
}
