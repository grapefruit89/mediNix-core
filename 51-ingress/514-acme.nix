# ---
# id: "514-acme"
# title: "Flake-managed ACME (Lego) with Cloudflare DNS-01"
# domain: 51
# folder: 51-ingress
# status: active
# last_reviewed: 2026-09-02
# provides: ["acme", "tls"]
# adr: ADR-514
# ---
# One token source, same order as 513. No tokenFile.
#   ingress.tls.acmeCredential
#   dns.ddns.cloudflareTokenCredential
#   dns.ddns.tokenCredential
{ lib, config, ... }:

let
  cfg = config.medinix;
  ing = cfg.ingress;
  ddns = cfg.dns.ddns;
  acmeHost = ing.tls.acmeHost;

  credPath =
    if (ing.tls.acmeCredential or null) != null then ing.tls.acmeCredential
    else if (ddns.cloudflareTokenCredential or null) != null then ddns.cloudflareTokenCredential
    else if (ddns.tokenCredential or null) != null then ddns.tokenCredential
    else null;

  credRuntime = "/run/credentials/acme-${acmeHost}.service/cf-token";

  contactMail =
    if (cfg.domain or null) != null then "admin@${cfg.domain}"
    else "admin@${acmeHost}";

in
lib.mkIf (cfg.enable && ing.enable && acmeHost != null) {
  users.groups.caddy = { };

  assertions = [
    {
      assertion = credPath != null;
      message = ''
        [mediNix] acmeHost is set but no Cloudflare credential was provided.
        Set ingress.tls.acmeCredential or dns.ddns.cloudflareTokenCredential.
        Same file is used by 513. Ref: ADR-514.
      '';
    }
    {
      assertion = (ddns.tokenFile or null) == null;
      message = "[mediNix] dns.ddns.tokenFile is rejected. Use a systemd credential.";
    }
  ];

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = contactMail;
      group = "caddy";
      reloadServices = lib.mkDefault [ "caddy.service" ];
    };
    certs.${acmeHost} = {
      domain = acmeHost;
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
      LoadCredentialEncrypted = [ "cf-token:${credPath}" ];
      EnvironmentFile = [ credRuntime ];
    };
  };
}
