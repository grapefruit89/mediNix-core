# ---
# id: "513-cloudflare-dns"
# title: "Intelligent Split-Horizon Cloudflare DDNS (LAN vs WAN)"
# domain: 50
# folder: 51-ingress
# status: active
# complexity: 4
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-5130
# provides: ["ddns", "cloudflare", "split-horizon"]
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
# ADR-5130: Eigenes DDNS im standalone-Modus (dns.mode=standalone).
# Implementiert Split-Horizon DNS basierend auf der caddyClass:
# - WAN-Dienste (stream, public) erhalten die externe Public-IP.
# - LAN-Dienste (internal) erhalten die interne Private-IP.
# Schreibt A-Records via Cloudflare API. KEINE Proxy (orange cloud OFF) —
# Caddy terminiert TLS selbst, Cloudflare darf nicht MITM'en.
# Token via LoadCredentialEncrypted (bevorzugt) oder tokenFile.
{ lib, pkgs, config, ... }:

let
  cfg  = config.grapefruitMedia;
  ddns = cfg.dns.ddns;
  zone = if ddns.zone != null then ddns.zone else cfg.domain;

  registry        = (import ../lib/registry.nix { inherit lib; }).services;
  enabledServices = lib.filterAttrs (n: svc:
    cfg.${n}.enable or false && svc.port != null && svc.caddyClass != "none"
  ) registry;

  # Filter services by caddyClass to determine IP and Proxy mapping
  streamServices = lib.filterAttrs (n: svc: svc.caddyClass == "stream") enabledServices;
  publicServices = lib.filterAttrs (n: svc: svc.caddyClass == "public") enabledServices;
  lanServices    = lib.filterAttrs (n: svc: svc.caddyClass == "internal") enabledServices;

  streamDomains = lib.mapAttrsToList (n: svc: "${svc.name}.${cfg.domain}") streamServices;
  publicDomains = lib.mapAttrsToList (n: svc: "${svc.name}.${cfg.domain}") publicServices;
  lanDomains    = lib.mapAttrsToList (n: svc: "${svc.name}.${cfg.domain}") lanServices;

  # Build space-separated strings for the bash script
  streamDomainsStr = builtins.concatStringsSep " " streamDomains;
  publicDomainsStr = builtins.concatStringsSep " " publicDomains;
  lanDomainsStr    = builtins.concatStringsSep " " lanDomains;

in
lib.mkIf (cfg.enable && cfg.dns.mode == "standalone" && ddns.enable) {

  # systemd-Timer: DDNS-Sync basierend auf ddns.interval
  systemd.services.cloudflare-ddns = {
    description = "Intelligent Split-Horizon Cloudflare DDNS (mediNix-core)";
    wantedBy = [ "multi-user.target" ];
    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];
    
    path = [ pkgs.curl pkgs.jq pkgs.iproute2 ];

    serviceConfig = lib.mkMerge [
      # Verwende das network-Profil statt script, da wir curl+Internet brauchen!
      (import ../lib/hardening-profiles.nix { inherit lib; }).network
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
      set -euo pipefail

      ZONE="${zone}"
      STREAM_DOMAINS="${streamDomainsStr}"
      PUBLIC_DOMAINS="${publicDomainsStr}"
      LAN_DOMAINS="${lanDomainsStr}"

      # Resolve API Token
      if [ -f "$CREDENTIALS_DIRECTORY/cf-ddns-token" ]; then
        TOKEN_FILE="$CREDENTIALS_DIRECTORY/cf-ddns-token"
      elif [ -n "''${CF_API_TOKEN_FILE:-}" ] && [ -f "$CF_API_TOKEN_FILE" ]; then
        TOKEN_FILE="$CF_API_TOKEN_FILE"
      else
        echo "FATAL: Cloudflare API token not found." >&2
        exit 1
      fi
      
      # Unterstütze sowohl reinen Text (alt) als auch CF_DNS_API_TOKEN=... (für ACME Kompatibilität)
      if grep -q "^CF_DNS_API_TOKEN=" "$TOKEN_FILE"; then
        TOKEN=$(grep "^CF_DNS_API_TOKEN=" "$TOKEN_FILE" | cut -d'=' -f2-)
      else
        TOKEN=$(cat "$TOKEN_FILE")
      fi

      echo "Fetching current IPs..."
      # Dynamische WAN IP Ermittlung
      WAN_IP=$(curl -s4 --fail-with-body https://ifconfig.me || curl -s4 --fail-with-body https://api.ipify.org)
      if [ -z "$WAN_IP" ]; then
        echo "FATAL: Could not determine WAN IP." >&2
        exit 1
      fi
      
      LAN_IP=$(ip -4 route get 8.8.8.8 | grep -oP 'src \K\S+')
      if [ -z "$LAN_IP" ]; then
        echo "FATAL: Could not determine LAN IP." >&2
        exit 1
      fi

      echo "Detected WAN IP: $WAN_IP"
      echo "Detected LAN IP: $LAN_IP"

      # Get Zone ID
      ZONE_ID=$(curl -s --fail-with-body -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" | jq -e -r 'if .success then .result[0].id else empty end')

      if [ "$ZONE_ID" = "null" ] || [ -z "$ZONE_ID" ]; then
        echo "FATAL: Could not find Zone ID for $ZONE." >&2
        exit 1
      fi

      update_record() {
        local record_name="$1"
        local ip="$2"
        local proxied="$3"
        
        echo "Processing $record_name -> $ip (proxied: $proxied)"
        
        # IPv6 (AAAA) radikal löschen, um IPv6 Leaks zu verhindern (P0.2)
        local aaaa_records=$(curl -s --fail-with-body -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$record_name&type=AAAA" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json")
        if echo "$aaaa_records" | jq -e '.success' > /dev/null; then
          for id in $(echo "$aaaa_records" | jq -r '.result[].id'); do
            echo "  Deleting leaking AAAA record $id..."
            curl -s --fail-with-body -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$id" \
              -H "Authorization: Bearer $TOKEN" \
              -H "Content-Type: application/json" > /dev/null
          done
        fi

        # IPv4 (A) updaten
        local record_info=$(curl -s --fail-with-body -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$record_name&type=A" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json")
          
        local record_id=$(echo "$record_info" | jq -r '.result[0].id // empty')
        local current_ip=$(echo "$record_info" | jq -r '.result[0].content // empty')
        local current_proxied=$(echo "$record_info" | jq -r '.result[0].proxied // empty')
        
        if [ -z "$record_id" ]; then
          echo "  Record not found. Creating..."
          curl -s --fail-with-body -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            --data '{"type":"A","name":"'"$record_name"'","content":"'"$ip"'","ttl":1,"proxied":'"$proxied"',"comment":"managed-by=mediNix-core/513"}' | jq -e '.success' > /dev/null
        elif [ "$current_ip" != "$ip" ] || [ "$current_proxied" != "$proxied" ]; then
          echo "  IP or proxy status changed. Updating..."
          curl -s --fail-with-body -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            --data '{"type":"A","name":"'"$record_name"'","content":"'"$ip"'","ttl":1,"proxied":'"$proxied"',"comment":"managed-by=mediNix-core/513"}' | jq -e '.success' > /dev/null
        else
          echo "  IP and proxy status match. No update needed."
        fi
      }

      for domain in $STREAM_DOMAINS; do
        update_record "$domain" "$WAN_IP" "false"
      done

      for domain in $PUBLIC_DOMAINS; do
        update_record "$domain" "$WAN_IP" "true"
      done

      for domain in $LAN_DOMAINS; do
        update_record "$domain" "$LAN_IP" "false"
      done

      echo "DDNS sync completed successfully."
    '';
  };

  systemd.timers.cloudflare-ddns = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnUnitActiveSec = ddns.interval;
      OnBootSec = "5m";
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
