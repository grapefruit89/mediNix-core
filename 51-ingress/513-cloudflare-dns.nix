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
# ADR-5130: Custom DDNS in standalone mode (dns.mode=standalone).
# Implements Split-Horizon DNS based on caddyClass:
# - WAN services (stream, public) receive the external public IP.
# - LAN services (internal) receive the internal private IP.
# Writes A-Records via Cloudflare API. NO Proxy (orange cloud OFF) —
# Caddy terminates TLS itself, Cloudflare must not MITM.
# Token via LoadCredentialEncrypted (preferred) or tokenFile.
{ lib, pkgs, config, ... }:

let
  cfg  = config.grapefruitMedia;
  ddns = cfg.dns.ddns;
  zone = if ddns.zone != null then ddns.zone else cfg.domain;

  registry        = (import ../lib/registry.nix { inherit lib; }).services;
  enabledServices = lib.filterAttrs (n: vhost:
    cfg.${n}.enable or false && (registry.${n}.port or null) != null
  ) cfg.ingress.vhosts;

  # Filter services by accessGroup to determine IP and Proxy mapping
  streamServices = lib.filterAttrs (n: vhost: vhost.accessGroup == "stream") enabledServices;
  publicServices = lib.filterAttrs (n: vhost: vhost.accessGroup == "public") enabledServices;
  lanServices    = lib.filterAttrs (n: vhost: vhost.accessGroup == "internal") enabledServices;
  effectiveDomain = if zone != null then zone else (if cfg.domain != null then cfg.domain else "local");
  streamDomains = lib.mapAttrsToList (n: vhost: "${registry.${n}.name}.${effectiveDomain}") streamServices;
  publicDomains = lib.mapAttrsToList (n: vhost: "${registry.${n}.name}.${effectiveDomain}") publicServices;
  lanDomains    = lib.mapAttrsToList (n: vhost: "${registry.${n}.name}.${effectiveDomain}") lanServices;

  # Build space-separated strings for the bash script
  streamDomainsStr = builtins.concatStringsSep " " streamDomains;
  publicDomainsStr = builtins.concatStringsSep " " publicDomains;
  lanDomainsStr    = builtins.concatStringsSep " " lanDomains;

in
lib.mkIf (cfg.enable && cfg.dns.mode == "standalone" && ddns.enable) {

  # systemd-Timer: DDNS-Sync basierend auf ddns.interval
  systemd.services.cloudflare-ddns = lib.mkMerge [
    ((import ../lib/service-factory.nix { inherit lib config pkgs; }) {
      name = "cloudflare-ddns";
      profile = "network";
      stateDir = "/var/lib/cloudflare-ddns";
      hardeningOnly = true;
      extraConfig = {
        Type            = "oneshot";
        # Token from systemd-credentials (ADR-5000)
        LoadCredentialEncrypted = lib.mkIf (ddns.tokenCredential != null)
          "cf-ddns-token:${ddns.tokenCredential}";
      };
    })
    {
      description = "Intelligent Split-Horizon Cloudflare DDNS (mediNix-core)";
      wantedBy = [ "multi-user.target" ];
      after    = [ "network-online.target" ];
      wants    = [ "network-online.target" ];
      
      path = [ pkgs.curl pkgs.jq pkgs.iproute2 ];

      # Alternative token via EnvironmentFile (agenix/sops-nix)
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
      
      # Support pure text (old) as well as CF_DNS_API_TOKEN=... (for ACME compatibility)
      if grep -q "^CF_DNS_API_TOKEN=" "$TOKEN_FILE"; then
        TOKEN=$(grep "^CF_DNS_API_TOKEN=" "$TOKEN_FILE" | cut -d'=' -f2-)
      else
        TOKEN=$(cat "$TOKEN_FILE")
      fi

      echo "Fetching current IPs..."
      # Dynamic WAN IP discovery
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
        
        # Radically delete IPv6 (AAAA) to prevent IPv6 leaks (P0.2)
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

        # Update IPv4 (A)
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
        sleep 0.5
      done

      for domain in $PUBLIC_DOMAINS; do
        update_record "$domain" "$WAN_IP" "true"
        sleep 0.5
      done

      for domain in $LAN_DOMAINS; do
        update_record "$domain" "$LAN_IP" "false"
        sleep 0.5
      done

      echo "DDNS sync completed successfully."
    '';
    }
  ];

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
