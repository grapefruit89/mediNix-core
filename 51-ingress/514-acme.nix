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
# requires: ["options.medinix"]
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
  cfg      = config.medinix;
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
        assertion = cfg.ingress.tls.acmeHost != null -> (cfg.ingress.tls.acmeCredential != null || cfg.dns.ddns.cloudflareTokenCredential != null || cfg.dns.ddns.tokenCredential != null || cfg.dns.ddns.tokenFile != null);
        message = ''
          [mediNix] acmeHost requires at least one token source (acmeCredential or a DDNS token).
          
          [AI/Admin Context]
          Reason: To fulfill a DNS-01 ACME challenge for Let's Encrypt, the lego client must inject a TXT record. It needs API credentials to do so.
          Ref: ADR-5043
        '';
      }
    ];

  security.acme = {
    acceptTerms = true;

    defaults = {
      # Let's Encrypt contact address (expiration warnings)
      email = "admin@${cfg.domain}";

      # P0.3: Wildcard key must NOT belong to the broad "media" group (blast radius).
      # Certificate group is limited to the Caddy process only.
      group = "caddy";

      # Reload Caddy after certificate renewal
      reloadServices =
        [ "caddy.service" ];
    };

    certs.${acmeHost} = {
      domain           = acmeHost;
      extraDomainNames = [ "*.${acmeHost}" ];

      # DNS-01 Challenge via Cloudflare
      dnsProvider = "cloudflare";

      # Lego-Tuning to prevent propagation timeouts (P0.4/Audit Idea)
      environment = {
        CLOUDFLARE_DNS_RESOLVERS = "1.1.1.1,1.0.0.1";
        CLOUDFLARE_POLLING_INTERVAL = "10";
        CLOUDFLARE_PROPAGATION_TIMEOUT = "120";
      };
      
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
      EnvironmentFile = [ credRuntime ];
    };
  };
}
