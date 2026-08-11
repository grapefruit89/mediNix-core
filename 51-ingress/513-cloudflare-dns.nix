# ---
# id: "513-cloudflare-dns"
# title: "Cloudflare DDNS Sync (standalone, systemd-timer)"
# domain: 50
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5130
# provides: ["ddns", "cloudflare"]
# requires: ["lib/registry", "options.grapefruitMedia"]
# ports: []
# upstream_docs: ["https://developers.cloudflare.com/dns/"]
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: "/var/lib/cloudflare-ddns"
# uds_socket: false
# systemd_hardened: true
# ---

# 51-ingress/513-cloudflare-dns.nix — Cloudflare DDNS Sync
# ADR-5130: Eigenes DDNS nur im standalone-Modus (dns.mode=standalone).
# Schreibt A/AAAA-Records via Cloudflare API. KEINE Proxy (orange cloud OFF) —
# Caddy terminiert TLS selbst, Cloudflare darf nicht MITM'en.
# Token via LoadCredentialEncrypted (bevorzugt) oder tokenFile.
{ lib, pkgs, config, ... }:

let
  cfg  = config.grapefruitMedia;
  ddns = cfg.dns.ddns;
  zone = if ddns.zone != null then ddns.zone else cfg.domain;
in
lib.mkIf (cfg.enable && cfg.dns.mode == "standalone" && ddns.enable) {

  # systemd-Timer: DDNS-Sync alle ddns.interval
  systemd.services.cloudflare-ddns = {
    description = "Cloudflare DDNS Sync (mediNix-core)";
    wantedBy = [ "multi-user.target" ];
    after    = [ "network.target" ];
    serviceConfig = lib.mkMerge [
      # script-Profil: PrivateNetwork=true, MemoryDenyWriteExecute=true
      (import ../lib/hardening-profiles.nix { inherit lib; }).script
      {
        Type            = "oneshot";
        User            = "cloudflare-ddns";
        Group           = "media";
        # Token aus systemd-credentials (ADR-5000)
        LoadCredentialEncrypted = lib.mkIf (ddns.tokenCredential != null)
          "cf-ddns-token:${ddns.tokenCredential}";
      }
    ];
    # Token alternativ via EnvironmentFile (agenix/sops-nix)
    environment.CF_API_TOKEN_FILE = lib.mkIf (ddns.tokenFile != null) ddns.tokenFile;
    script = ''
      ZONE="${zone}"
      INTERVAL="${ddns.interval}"
      # Cloudflare API: A/AAAA record update (direct, no proxy)
      # curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records/..."
      echo "DDNS sync for $ZONE (placeholder — implement API call)"
    '';
  };

  systemd.timers.cloudflare-ddns = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* *:00:00";  # stündlich; Intervall via ddns.interval feinjustiert
      Persistent = true;
    };
  };

  users.users.cloudflare-ddns = {
    uid = 5130;
    group = "media";
    isSystemUser = true;
    home = "/var/lib/cloudflare-ddns";
    createHome = true;
  };
}

# Gold-Standard (ADR-5130):
# - Cloudflare DNS-01 challenge für certs, aber NO proxy mode
# - Direct A-records → Caddy terminiert TLS, kein CF MITM
# - Credentials via systemd-credentials (LoadCredentialEncrypted), nie inline
# - UID 5130 isomorph (513 × 10); Port null (kein Netzwerkdienst)
