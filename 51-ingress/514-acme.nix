# ---
# id: "514-acme"
# title: "Native NixOS ACME (Lego) with Cloudflare DNS-01 Challenge"
# domain: 50
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-5140
# provides: ["acme", "tls", "certificates"]
# requires: ["options.grapefruitMedia"]
# ports: []
# upstream_docs: ["https://nixos.wiki/wiki/ACME", "https://go-acme.github.io/lego/dns/cloudflare/"]
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: "security.acme"
# state_dir: "/var/lib/acme"
# uds_socket: false
# systemd_hardened: true
# ---

# 51-ingress/514-acme.nix — Native NixOS ACME Certificate Management
# ADR-5140: Certificates are NOT managed by Caddy, but natively by NixOS (Lego).
# Uses the DNS-01 challenge via Cloudflare API. Therefore, no ports (80/443)
# need to be opened to the internet to obtain certificates. Perfect for pure LAN services.
# Generates a wildcard certificate (*.domain.tld) which Caddy then consumes.
{ lib, config, ... }:

let
  cfg = config.grapefruitMedia;
  ing = cfg.ingress;
  acmeHost = ing.tls.acmeHost;

  # We use the same token path as the DDNS module, but expect
  # the format for Lego here: CF_DNS_API_TOKEN=YourToken
  tokenFile = cfg.dns.ddns.tokenFile;
in
lib.mkIf (cfg.enable && ing.enable && acmeHost != null) {

  security.acme = {
    acceptTerms = true;
    
    defaults = {
      # Email address for Let's Encrypt (important for expiration warnings)
      email = "admin@${cfg.domain}"; 
      
      # P0.3: Wildcard key must never belong to the entire "media" group (Blast Radius).
      # Belongs exclusively to the Caddy process.
      group = if config.services.caddy.enable then config.services.caddy.group else "caddy-media"; 
      
      # Reload command for Caddy after a certificate update
      reloadServices = if config.services.caddy.enable then [ "caddy.service" ] else [ "caddy-media.service" ];
    };

    certs.${acmeHost} = {
      # Main domain and wildcard
      domain = acmeHost;
      extraDomainNames = [ "*.${acmeHost}" ];
      
      # DNS-01 Challenge via Cloudflare
      dnsProvider = "cloudflare";
      
      # credentialsFile must be a file containing the following:
      # CF_DNS_API_TOKEN=your_cloudflare_token
      credentialsFile = lib.mkIf (tokenFile != null) tokenFile;
    };
  };

  # If the token is available as a systemd LoadCredentialEncrypted (like in DDNS)
  systemd.services."acme-${acmeHost}" = lib.mkIf (cfg.dns.ddns.tokenCredential != null) {
    serviceConfig.LoadCredentialEncrypted = [ "cf-api-token:${cfg.dns.ddns.tokenCredential}" ];
    # We overwrite EnvironmentFile because security.acme maps credentialsFile there by default
    serviceConfig.EnvironmentFile = lib.mkForce [ "/run/credentials/acme-${acmeHost}/cf-api-token" ];
  };
}
