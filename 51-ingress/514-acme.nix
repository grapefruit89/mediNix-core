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
# ACME uses its OWN Cloudflare token (never the DDNS token). No tokenFile.
#   ingress.tls.acmeCredential
# Scope: Zone:DNS:Edit on exactly this zone (TXT _acme-challenge). Keep it
# separate from the DDNS token so a DDNS compromise cannot break TLS issuance.
{ lib, config, pkgs, ... }:

let
  cfg = config.medinix;
  ing = cfg.ingress;
  ddns = cfg.dns.ddns;
  acmeHost = ing.tls.acmeHost;

  credPath = ing.tls.acmeCredential or null;

  credRuntime = "/run/credentials/acme-${acmeHost}.service/cf-token";

  # Extra lego/Cloudflare tuning env. nixpkgs' cert option is `environmentFile`
  # (a path), NOT `environment` (a map) — and it would clash with our sealed
  # token EnvironmentFile below. So these vars live in their own env file (no
  # secrets). Replaces the former invalid `environment = { CLOUDFLARE_* }`.
  cfTuningEnv = pkgs.writeText "acme-cloudflare-tuning.env" ''
    CLOUDFLARE_POLLING_INTERVAL=10
    CLOUDFLARE_PROPAGATION_TIMEOUT=120
  '';

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
        [mediNix] acmeHost is set but no dedicated ACME credential was provided.
        Set ingress.tls.acmeCredential (its OWN token, NOT the DDNS one).
        Ref: ADR-514.
      '';
    }
    {
      assertion = !(ddns.enable
        && (ddns.cloudflareTokenCredential or null) != null
        && ing.tls.acmeCredential == ddns.cloudflareTokenCredential);
      message = ''
        [mediNix] ACME and DDNS must use SEPARATE Cloudflare credentials.
        ingress.tls.acmeCredential == dns.ddns.cloudflareTokenCredential.
        Two tokens limit the blast radius. Ref: ADR-514 / ADR-5130.
      '';
    }
    {
      assertion = (ddns.tokenFile or null) == null;
      message = "[mediNix] dns.ddns.tokenFile is rejected. Use a systemd credential.";
    }
    {
      # F6: the wildcard cert *.{acmeHost} must actually cover the vHosts
      # rendered as {name}.{domain}.
      assertion =
        cfg.domain == null
        || cfg.domain == ing.tls.acmeHost
        || lib.hasSuffix ".${ing.tls.acmeHost}" cfg.domain;
      message = ''
        [mediNix] tls.acmeHost = "${ing.tls.acmeHost}" does not cover
        domain = "${cfg.domain}". The cert is *.{acmeHost} but the vHosts are
        {name}.{domain}. Use domain == acmeHost or a subdomain of acmeHost.
      '';
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
      # lego DNS resolver. (The former `environment = { CLOUDFLARE_* }` block
      # referenced security.acme.certs.<name>.environment, which does not exist
      # in nixpkgs — it broke the whole acmeHost evaluation.)
      dnsResolver = "1.1.1.1:53";
    };
  };

  systemd.services."acme-${acmeHost}" = {
    serviceConfig = {
      EnvironmentFile = [ credRuntime cfTuningEnv ];
    } // lib.optionalAttrs (credPath != null) {
      LoadCredentialEncrypted = [ "cf-token:${credPath}" ];
    };
  };
}
