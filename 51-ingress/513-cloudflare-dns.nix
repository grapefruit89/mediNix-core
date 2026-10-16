# ---
# id: "513-cloudflare-dns"
# title: "Anchor DDNS — wan + lan A, wildcard/apex CNAME to wan (organ of 511)"
# domain: 51
# folder: 51-ingress
# status: active
# last_reviewed: 2026-10-02
# provides: ["ddns", "cloudflare"]
# requires: ["lib/service-factory"]
# adr: ADR-5130
# links:
#   adr: ADR-513-cloudflare-dns
# ---
# DDNS uses its OWN Cloudflare token (never the ACME token). No tokenFile.
#   dns.ddns.cloudflareTokenCredential
# Scope: Zone:DNS:Edit on exactly this zone (needs delete for the prune step).
# Keep it separate from the ACME token so a DDNS compromise cannot also break
# TLS issuance (R11).
# Loaded as cf-ddns-token. File is the token or KEY=value.
#
# INVARIANT — 1 service, exactly 2 canonical addresses:
#   {service}.local          (515)
#   {service}.${cfg.domain}  (511)
# `dns.ddns.zone` is the Cloudflare zone (API/zone target only) and MUST NEVER
# derive a service hostname. 513 prunes ONLY the canonical {label}.${cfg.domain},
# never {label}.${zone} — a mismatched zone must not be able to delete an
# unrelated record.
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.medinix;
  ddns = cfg.dns.ddns;
  df = import ../lib/derive.nix;
  cfStateDir = "/var/lib/cloudflare-ddns";
  cfUid = (df.derive "cloudflare-ddns" 513).uid; # 5130
  domain = if cfg.host.domain != null then cfg.host.domain else cfg.domain;
  zone = if ddns.zone != null then ddns.zone else domain;

  manifestWanServices = lib.filterAttrs (
    _: m:
    m.enable
    && lib.elem (m.accessGroup or "none") [
      "public"
      "stream"
      "idp"
    ]
  ) (config.medinix.manifest or { });
  vhosts = cfg.ingress.vhosts or { };
  aliases = cfg.dns.hostnames or { };

  ownedLabels = lib.unique (
    lib.attrNames manifestWanServices ++ lib.attrNames vhosts ++ lib.attrValues aliases
  );

  reservedLabels = [
    "wan"
    "lan"
    "*"
    "@"
  ];

  isProtectedLabel =
    n:
    n == ""
    || builtins.elem n reservedLabels
    || (zone != null && n == zone)
    || lib.hasPrefix "_acme-challenge" n;

  # Canonical public FQDN is ALWAYS {label}.${domain}; the Cloudflare zone
  # is never used to build a service hostname (see INVARIANT above).
  pruneNames = lib.filter (n: !isProtectedLabel n) ownedLabels;
  pruneFqdns = lib.optionals (domain != null) (map (n: "${n}.${domain}") pruneNames);
  pruneNamesStr = builtins.concatStringsSep " " pruneFqdns;

  credPath = ddns.cloudflareTokenCredential or null;

in
lib.mkIf (cfg.enable && cfg.dns.mode == "standalone" && ddns.enable) {

  assertions = [
    {
      assertion = credPath != null;
      message = ''
        [mediNix] DDNS is on but no dedicated Cloudflare credential was set.
        Set dns.ddns.cloudflareTokenCredential (its OWN token, NOT the ACME one).
        dns.ddns.tokenFile is not accepted. Ref: ADR-5130.
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
      uid = cfUid; # 513 x 10: UID = Primaer-GID (UPG, ADR-0000 §4)
      profile = "network";
      stateDir = cfStateDir;
      hardeningOnly = true;
      extraConfig = {
        Type = "oneshot";
        # 0700: hier legt das Skript gleich die Token-Datei fuer curl --variable ab.
        RuntimeDirectoryMode = "0700";
        # Kein Nachladen aus /tmp, Home oder einem Angreifer-Verzeichnis:
        # nur der Nix-Store ist ausfuehrbar. Idiom aus nixpkgs
        # (z. B. webdav-server-rs.nix:129-130, meme-bingo-web.nix:129-130).
        # Das Script nutzt ausschliesslich Store-Pfade (curl, jq, ip, gawk, gnugrep).
        NoExecPaths = [ "/" ];
        ExecPaths = [ "/nix/store" ];
      }
      // lib.optionalAttrs (credPath != null) {
        LoadCredentialEncrypted = [ "cf-ddns-token:${credPath}" ];
      };
    })
    {
      description = "mediNix-core 513 anchor DDNS (wan + lan, wildcard → wan)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = [
        pkgs.curl
        pkgs.jq
        pkgs.iproute2
        pkgs.gawk
        pkgs.gnugrep
      ];

      script = ''
        set -euo pipefail

        ZONE="${zone}"
        PRUNE_NAMES="${pruneNamesStr}"
        STATE_FILE="${cfStateDir}/state.json"
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

        # Der Token darf NIE in argv landen (ps, /proc/<pid>/cmdline): curl liest
        # ihn per --variable aus einer 0600-Datei im RuntimeDirectory (tmpfs) und
        # expandiert ihn erst im Prozess (--expand-header, curl >= 8.3).
        (umask 077; printf '%s' "$TOKEN" > "$RUNTIME_DIRECTORY/cf-token")
        AUTH=(--variable token@"$RUNTIME_DIRECTORY/cf-token" --expand-header "Authorization: Bearer {{token:trim}}")
        unset TOKEN

        WAN_IP=$(curl -s4 --fail-with-body https://ifconfig.me || curl -s4 --fail-with-body https://api.ipify.org)
        if [ -z "$WAN_IP" ]; then
          echo "FATAL: Could not determine WAN IP." >&2
          exit 1
        fi
        # RT-4: third-party echo services are a trusted NETWORK, not trusted
        # DATA. Any 200-body (error page, captive portal, garbage) must never
        # reach the Cloudflare API — validate the format before using it.
        if ! printf '%s' "$WAN_IP" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
          echo "FATAL: WAN_IP is not a valid IPv4: '$WAN_IP'" >&2
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
        if ! printf '%s' "$LAN_IP" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
          echo "FATAL: LAN_IP is not a valid IPv4: '$LAN_IP'" >&2
          exit 1
        fi
        echo "Detected WAN IP: $WAN_IP"
        echo "Detected LAN IP: $LAN_IP"

        ZONE_ID=$(curl -s --fail-with-body "''${AUTH[@]}" -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE" \
          -H "Content-Type: application/json" | jq -e -r 'if .success then .result[0].id else empty end')

        if [ "$ZONE_ID" = "null" ] || [ -z "$ZONE_ID" ]; then
          echo "FATAL: Could not find Zone ID for $ZONE." >&2
          exit 1
        fi

        cf() {
          local method="$1" url="$2" data="''${3:-}"
          if [ -n "$data" ]; then
            curl -s --fail-with-body "''${AUTH[@]}" -X "$method" "$url" \
              -H "Content-Type: application/json" \
              --data "$data"
          else
            curl -s --fail-with-body "''${AUTH[@]}" -X "$method" "$url" \
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
        # RT-4: lan.{zone} publishes a private RFC1918 address to PUBLIC DNS —
        # recon gold for attackers, zero external benefit (split-DNS is
        # host-side, ADR-5115). Opt-in via dns.ddns.publishLanRecord; when
        # off, actively remove leftovers from earlier runs (self-healing).
        ${lib.optionalString ddns.publishLanRecord ''
          update_record "lan.$ZONE" "A" "$LAN_IP"
        ''}${
          lib.optionalString (!ddns.publishLanRecord) ''
            echo "  lan record: publishLanRecord=false — pruning public RFC1918 leftovers"
            prune_label "lan.$ZONE"
          ''
        }
        # RT-8: a wildcard covers exactly ONE label below the zone. With
        # domain != zone (e.g. home.example.com under example.com) the service
        # FQDNs {label}.{domain} are NOT covered by *.{zone} — split-DNS stays
        # host-side (ADR-5115); see the dns.ddns.zone option description.
        update_record "*.$ZONE" "CNAME" "wan.$ZONE"
        update_record "$ZONE" "CNAME" "wan.$ZONE"
        # PRUNE_NAMES holds canonical FQDNs ({label}.''${cfg.domain}), built in
        # Nix — the zone must not be appended here.
        for n in $PRUNE_NAMES; do
          [ -z "$n" ] && continue
          prune_label "$n"
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

  # Dieses Modul baut seine Unit selbst und nutzt die Fabrik nur als
  # Hardening-Injektion (hardeningOnly): dort ist der Rueckgabewert die
  # UNIT-Definition, deshalb liefert die Fabrik in diesem Modus bewusst keine
  # users.* (die landeten sonst innerhalb der Unit). User/Group/RuntimeDirectory
  # setzt sie trotzdem (ownsAccount), den Account legt dieses Modul an - mit UPG
  # (ADR-0000 §4: Primaergruppe = Name, GID = uid). media (5000) waere hier
  # ohnehin unrecht: das Skript braucht keinen Medienzugriff.
  users.groups.cloudflare-ddns = {
    gid = cfUid;
  };
  users.users.cloudflare-ddns = {
    uid = cfUid;
    group = "cloudflare-ddns";
    isSystemUser = true;
    home = cfStateDir;
    createHome = true;
  };

  # In medinix.factoryUnits eintragen, damit Guardrail 591 diese Unit prueft
  # (User/Group = UPG, StateDirectory, uid/gid). Der Modul-Modus macht das
  # automatisch, der hardeningOnly-Modus nicht.
  medinix.factoryUnits."cloudflare-ddns" = {
    uid = cfUid;
    stateDir = cfStateDir;
  };
}
