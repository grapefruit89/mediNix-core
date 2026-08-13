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
# ADR-5140: Zertifikate werden NICHT von Caddy verwaltet, sondern nativ von NixOS (Lego).
# Nutzt die DNS-01 Challenge via Cloudflare API. Dadurch müssen keine Ports (80/443) 
# ins Internet geöffnet sein, um Zertifikate zu beziehen. Perfekt für reine LAN-Dienste.
# Erzeugt ein Wildcard-Zertifikat (*.domain.tld), das Caddy dann konsumiert.
{ lib, config, ... }:

let
  cfg = config.grapefruitMedia;
  ing = cfg.ingress;
  acmeHost = ing.tls.acmeHost;

  # Wir nutzen denselben Token-Pfad wie das DDNS-Modul, erwarten hier aber 
  # das Format für Lego: CF_DNS_API_TOKEN=DeinToken
  tokenFile = cfg.dns.ddns.tokenFile;
in
lib.mkIf (cfg.enable && ing.enable && acmeHost != null) {

  security.acme = {
    acceptTerms = true;
    
    defaults = {
      # E-Mail-Adresse für Let's Encrypt (wichtig für Ablaufwarnungen)
      email = "admin@${cfg.domain}"; 
      
      # P0.3: Wildcard-Key darf niemals der ganzen "media" Gruppe gehören (Blast Radius).
      # Gehört exklusiv dem Caddy-Prozess.
      group = if config.services.caddy.enable then config.services.caddy.group else "caddy-media"; 
      
      # Reload-Befehl für Caddy nach einem Zertifikats-Update
      reloadServices = if config.services.caddy.enable then [ "caddy.service" ] else [ "caddy-media.service" ];
    };

    certs.${acmeHost} = {
      # Hauptdomain und Wildcard
      domain = acmeHost;
      extraDomainNames = [ "*.${acmeHost}" ];
      
      # DNS-01 Challenge über Cloudflare
      dnsProvider = "cloudflare";
      
      # credentialsFile muss eine Datei sein, die folgendes enthält:
      # CF_DNS_API_TOKEN=dein_cloudflare_token
      credentialsFile = lib.mkIf (tokenFile != null) tokenFile;
    };
  };

  # Falls das Token als systemd LoadCredentialEncrypted vorliegt (wie bei DDNS)
  systemd.services."acme-${acmeHost}" = lib.mkIf (cfg.dns.ddns.tokenCredential != null) {
    serviceConfig.LoadCredentialEncrypted = [ "cf-api-token:${cfg.dns.ddns.tokenCredential}" ];
    # Wir überschreiben EnvironmentFile, da security.acme standardmäßig credentialsFile dorthin mappt
    serviceConfig.EnvironmentFile = lib.mkForce [ "/run/credentials/acme-${acmeHost}/cf-api-token" ];
  };
}
