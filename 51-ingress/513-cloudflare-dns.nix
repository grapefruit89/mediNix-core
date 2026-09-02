# ---
# id: "513-cloudflare-dns"
# title: "Anchor DDNS — wan + lan A, wildcard/apex CNAME to wan (organ of 511)"
# domain: 50
# folder: 51-ingress
# status: active
# last_reviewed: 2026-09-02
# provides: ["ddns", "cloudflare"]
# requires: ["lib/service-factory"]
# adr: ADR-5130
# ---
# Same token source as 514. No plaintext tokenFile.
#   1. ingress.tls.acmeCredential
#   2. dns.ddns.cloudflareTokenCredential
#   3. dns.ddns.tokenCredential
# Loaded as cf-ddns-token. File is the token or KEY=value.
{ lib, pkgs, config, ... }:

let
  cfg  = config.medinix;
  ing  = cfg.ingress;
  ddns = cfg.dns.ddns;
  zone = if ddns.zone != null then ddns.zone else cfg.domain;

  vhosts = cfg.ingress.vhosts or {};
  aliases = cfg.dns.hostnames or {};

  ownedLabels = lib.unique (
    lib.attrNames vhosts
    ++ lib.attrValues aliases
  );

  reservedLabels = [ "wan" "lan" "*" "@" ];

  isProtectedLabel = n:
    n == ""
    || builtins.elem n reservedLabels
    || (zone != null && n == zone)
    || lib.hasPrefix "_acme-challenge" n;

  pruneNames = lib.filter (n: !isProtectedLabel n) ownedLabels;
  pruneNamesStr = builtins.concatStringsSep " " pruneNames;

  credPath =
    if      (ing.tls.acmeCredential or null) != null then ing.tls.acmeCredential
    else if ddns.cloudflareTokenCredential   != null then ddns.cloudflareTokenCredential
    else if ddns.tokenCredential             != null then ddns.tokenCredential
    else null;

in
lib.mkIf (cfg.enable && cfg.dns.mode == "standalone" && ddns.enable) {

  assertions = [
    {
      assertion = credPath != null;
      message = ''
        [mediNix] DDNS is on but no Cloudflare credential was set.
        Use ingress.tls.acmeCredential or dns.ddns.cloudflareTokenCredential.
        dns.ddns.tokenFile is not accepted. Same file as 514. Ref: ADR-5130.
      '';
    }
    {
      assertion = (ddns.tokenFile or null) == null;
      message = ''
        [mediNix] dns.ddns.tokenFile is rejected. Seal the token with
        systemd-creds and point acmeCredential / cloudflareTokenCredential
        at the .cred blob.
      '';
    }
    {
      assertion = zone != null;
      message = ''
        [mediNix] DDNS is enabled but neither dns.ddns.zone nor medinix.domain is set.
        Ref: ADR-5130
      '';
    }
  ];

  systemd.services.cloudflare-ddns = lib.mkMerge [
    ((import ../lib/service-factory.nix { inherit lib config pkgs; }) {
      name = "cloudflare-ddns";
      profile = "network";
      stateDir = "/var/lib/cloudflare-ddns";
      hardeningOnly = true;
      extraConfig = {
        Type = "oneshot";
        LoadCredentialEncrypted = [ "cf-ddns-token:${credPath}" ];
      };
    })
    {
      description = "mediNix-core 513 anchor DDNS (wan + lan, wildcard → wan)";
      wantedBy = [ "multi-user.target" ];
      after    = [ "network-online.target" ];
      wants    = [ "network-online.target" ];

      path = [ pkgs.curl pkgs.jq pkgs.iproute2 pkgs.gawk pkgs.gnugrep ];

      script = ''
        set -euo pipefail

        ZONE="${zone}"
        PRUNE_NAMES="${pruneNamesStr}"
        STATE_FILE="/var/lib/cloudflare-ddns/state.json"
        SCHEMA="anchor-v1"

        if [ -z "''${CREDENTIALS_DIRECTORY:-}" ] || [ ! -f "$CREDENTIALS_DIRECTORY/cf-ddns-token" ]; then
          echo "FATAL: sealed cf-ddns-token missing." >&2
          exit 1
        fi
        TOKEN_FILE="$CREDENTIALS_DIRECTORY/cf-ddns-token"

        if grep -q "^CF_DNS_API_TOKEN=" "$TOKEN_FILE"; then
          TOKEN=$(grep "^CF_DNS_API_TOKEN=" "$TOKEN_FILE" | cut -d'=' -f2-)
        elif grep -q "^CF_API_TOKEN=" "$TOKEN_FILE"; then
          TOKEN=$(grep "^CF_API_TOKEN=" "$TOKEN_FILE" | cut -d'=' -f2-)
        else
          TOKEN=$(cat "$TOKEN_FILE")
        fi

        WAN_IP=$(curl -s4 --fail-with-body https://ifconfig.me || curl -s4 --fail-with-body https://api.ipify.org)
        if [ -z "$WAN_IP" ]; then
          echo "FATAL: Could not determine WAN IP." >&2
          exit 1
        fi

        LAN_IP=$(ip -4 route get 1.1.1.1 2>/dev/null \
          | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')
        if [ -z "$LAN_IP" ]; then
          LAN_IP=$(ip -4 -o addr show scope global \
            | awk '{ split($4, a, "/"); print a[1]; exit }')
        fi
        if [ -z "$LAN_IP" ]; then
          echo "FATAL: Could not determine LAN IP." >&2
          exit 1
        fi

        echo "Detected WAN IP: $WAN_IP"
        echo "Detected LAN IP: $LAN_IP"

        ZONE_ID=$(curl -s --fail-with-body -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" | jq -e -r 'if .success then .result[0].id else empty end')

        if [ "$ZONE_ID" = "null" ] || [ -z "$ZONE_ID" ]; then
          echo "FATAL: Could not find Zone ID for $ZONE." >&2
          exit 1
        fi

        cf() {
          local method="$1" url="$2" data="''${3:-}"
          if [ -n "$data" ]; then
            curl -s --fail-with-body -X "$method" "$url" \
              -H "Authorization: Bearer $TOKEN" \
              -H "Content-Type: application/json" \
              --data "$data"
          else
            curl -s --fail-with-body -X "$method" "$url" \
              -H "Authorization: Bearer $TOKEN" \
              -H "Content-Type: application/json"
          fi
        }

        update_record() {
          local record_name="$1"
          local rtype="$2"
          local content="$3"
          local proxied="false"

          echo "Ensuring $record_name $rtype -> $content"

          local search_types="A AAAA CNAME"
          for stype in $search_types; do
            if [ "$stype" = "$rtype" ]; then continue; fi
            local records
            records=$(cf GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$record_name&type=$stype")
            if echo "$records" | jq -e '.success' > /dev/null; then
              for id in $(echo "$records" | jq -r '.result[].id'); do
                echo "  Deleting conflicting $stype $id"
                cf DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$id" > /dev/null
              done
            fi
          done

          local record_info
          record_info=$(cf GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$record_name&type=$rtype")
          local record_id current_content current_proxied
          record_id=$(echo "$record_info" | jq -r '.result[0].id // empty')
          current_content=$(echo "$record_info" | jq -r '.result[0].content // empty')
          current_proxied=$(echo "$record_info" | jq -r '.result[0].proxied // false')

          local payload
          payload=$(jq -n \
            --arg type "$rtype" \
            --arg name "$record_name" \
            --arg content "$content" \
            --argjson proxied "$proxied" \
            '{type:$type,name:$name,content:$content,ttl:1,proxied:$proxied,comment:"managed-by=mediNix-core/513"}')

          if [ -z "$record_id" ]; then
            echo "  Creating..."
            echo "$payload" | jq -c . >/dev/null
            cf POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" "$payload" | jq -e '.success' > /dev/null
          elif [ "$current_content" != "$content" ] || [ "$current_proxied" != "false" ]; then
            echo "  Updating ($current_content proxied=$current_proxied)..."
            cf PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" "$payload" | jq -e '.success' > /dev/null
          else
            echo "  Already correct."
          fi
        }

        prune_label() {
          local record_name="$1"
          local stype id records
          for stype in A AAAA CNAME; do
            records=$(cf GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$record_name&type=$stype")
            if ! echo "$records" | jq -e '.success' > /dev/null; then
              continue
            fi
            for id in $(echo "$records" | jq -r '.result[].id'); do
              echo "  Pruning leftover $stype $record_name ($id)"
              cf DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$id" > /dev/null
            done
          done
        }

        update_record "wan.$ZONE" "A" "$WAN_IP"
        update_record "lan.$ZONE" "A" "$LAN_IP"
        update_record "*.$ZONE" "CNAME" "wan.$ZONE"
        update_record "$ZONE" "CNAME" "wan.$ZONE"

        for n in $PRUNE_NAMES; do
          [ -z "$n" ] && continue
          case "$n" in
            wan|lan|"*"|@|_acme-challenge*) continue ;;
          esac
          prune_label "$n.$ZONE"
        done

        jq -n --arg wan "$WAN_IP" --arg lan "$LAN_IP" --arg schema "$SCHEMA" \
          '{wan:$wan,lan:$lan,schema:$schema}' > "$STATE_FILE"

        echo "DDNS anchor sync completed (schema $SCHEMA)."
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
