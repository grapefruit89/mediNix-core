# ---
# id: "513-ddns"
# title: "Anchor DDNS — wan + lan A, wildcard/apex CNAME to wan (organ of 511)"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 3
# last_reviewed: 2026-11-03
# provides: ["ddns"]
# requires: ["lib/service-factory"]
# adr: ADR-513
# links:
#   adr: ADR-513
# ---
# Orchestrator. Spricht NUR mit dem DNS-Provider (Cloudflare) und dem
# Router-Adapter (über medinix._internal.ddns.routerScripts).
# Weiß nichts über Speedport, OpenWrt oder Fritzbox — das ist im Adapter.
#
# Zwei Services:
#   cloudflare-ddns.service           → check (alle ddns.interval, idempotent)
#   cloudflare-ddns-reconnect.service → reconnect (05:00, EIN Reconnect, kein Retry)
#
# Login-Budget Speedport: 1 (reconnect) + N (checks) — kein Polling, keine
# Retry-Schleife im Orchestrator. Adapter macht alles in EINER Login-Session.
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

  ia = import ../lib/ingress-access.nix { inherit lib; };
  manifest = config.medinix.manifest or { };

  wanManifestLabels = lib.attrNames (
    lib.filterAttrs (n: m: m.enable && ia.isWan (ia.accessGroupOf cfg n m)) manifest
  );
  wanVhostLabels = lib.filter (n: ia.isWan (ia.accessGroupOf cfg n (manifest.${n} or { }))) (
    lib.attrNames (cfg.ingress.vhosts or { })
  );
  aliases = cfg.dns.hostnames or { };
  ownedLabels = lib.unique (wanManifestLabels ++ wanVhostLabels ++ lib.attrValues aliases);

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

  pruneNames = lib.filter (n: !isProtectedLabel n) ownedLabels;
  pruneFqdns = lib.optionals (domain != null) (map (n: "${n}.${domain}") pruneNames);
  pruneNamesStr = builtins.concatStringsSep " " pruneFqdns;

  credPath = ddns.cloudflareTokenCredential or null;

  # Vom Router-Adapter bereitgestellte Skripte (siehe 513-router-adapter-speedport.nix).
  # Leer = kein Router-Adapter konfiguriert → check nutzt externen Fallback.
  routerScripts = config.medinix._internal.ddns.routerScripts;
  hasReconnect = routerScripts ? reconnect;

  # ── Der gemeinsame Script-Generator ─────────────────────────────────────
  # Parametrisiert nach "check" oder "reconnect".
  # Generiert den Unit-Script-String inline, damit NixOS Tests den Payload
  # direkt auf c.systemd.services.cloudflare-ddns.script greppen können.
  mkDdnsScript = action: ''
    set -euo pipefail
    ACTION="${action}"

    # ── 1. IP vom Adapter holen ────────────────────────────────────────────
    if [ "$ACTION" = "reconnect" ]; then
      ${if hasReconnect then ''
        if ! WAN_IP=$("${routerScripts.reconnect}"); then
          echo "FATAL: router-adapter reconnect failed" >&2
          exit 1
        fi
      '' else ''
        echo "FATAL: reconnect requested but no router adapter configured" >&2
        exit 1
      ''}
    else
      ${if routerScripts ? check then ''
        if ! WAN_IP=$("${routerScripts.check}"); then
          echo "FATAL: router-adapter check failed" >&2
          exit 1
        fi
      '' else if ddns.wanIp.provider == "command" then ''
        ${ddns.wanIp.command or ""}
        if [ -z "''${WAN_IP:-}" ]; then
          echo "FATAL: custom command did not set WAN_IP" >&2
          exit 1
        fi
      '' else ''
        # Fallback: externe IP-Ermittlung
        WAN_IP=""
        for url in https://ifconfig.me https://api.ipify.org; do
          candidate=$(curl -s4 --fail-with-body "$url" || true)
          if printf '%s' "$candidate" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
            WAN_IP="$candidate"
            break
          fi
        done
        if [ -z "$WAN_IP" ]; then
          echo "FATAL: no WAN IP from external providers" >&2
          exit 1
        fi
      ''}
    fi

    # ── 2. IP validieren (doppelt — Adapter hat schon validiert) ────────────
    if ! printf '%s' "$WAN_IP" | grep -Eq '^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3}$'; then
      echo "FATAL: invalid IPv4: '$WAN_IP'" >&2
      exit 1
    fi
    case "$WAN_IP" in
      0.*|10.*|127.*|169.254.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*)
        echo "FATAL: non-public IPv4: $WAN_IP" >&2
        exit 1
        ;;
    esac
    echo "Adapter $ACTION delivered WAN_IP=$WAN_IP"

    # ── 3. Cloudflare-Update ────────────────────────────────────────────────
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

    (umask 077; printf '%s' "$TOKEN" > "$RUNTIME_DIRECTORY/cf-token")
    AUTH=(--variable token@"$RUNTIME_DIRECTORY/cf-token" --expand-header "Authorization: Bearer {{token:trim}}")
    unset TOKEN

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
        for id in $(echo "$records" | jq -r '.result[] | select(.comment == "managed-by=mediNix-core/513") | .id'); do
          echo "  Pruning leftover $stype $record_name ($id)"
          cf DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$id" > /dev/null
        done
        local foreign
        foreign=$(echo "$records" | jq -r '[.result[] | select(.comment != "managed-by=mediNix-core/513")] | length')
        if [ "''${foreign:-0}" != "0" ]; then
          echo "  Kept $foreign foreign $stype record(s) at $record_name - not ours, not touched" >&2
        fi
      done
    }

    update_record "wan.$ZONE" "A" "$WAN_IP"
    update_record "*.$ZONE" "CNAME" "wan.$ZONE"
    update_record "$ZONE" "CNAME" "wan.$ZONE"
    for n in $PRUNE_NAMES; do
      [ -z "$n" ] && continue
      prune_label "$n"
    done

    jq -n --arg wan "$WAN_IP" --arg schema "$SCHEMA" \
      '{wan:$wan,schema:$schema}' > "$STATE_FILE"

    echo "DDNS anchor sync completed (schema $SCHEMA)."
  '';

in
{
  options.medinix._internal.ddns.routerScripts = lib.mkOption {
    type = lib.types.attrsOf lib.types.path;
    default = { };
    internal = true;
    description = ''
      Vom Router-Adapter (z. B. 513-router-adapter-speedport.nix) bereitgestellte
      Skripte. Schlüssel "check" und "reconnect". Leer = kein Router-Adapter.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.dns.mode == "standalone" && ddns.enable) {

    assertions = [
      {
        assertion = credPath != null;
        message = ''
          [mediNix/513] DDNS is on but no dedicated Cloudflare credential was set.
          Set dns.ddns.cloudflareTokenCredential (its OWN token, NOT the ACME one).
          dns.ddns.tokenFile is not accepted. Ref: ADR-513.
        '';
      }
      {
        assertion = (ddns.tokenFile or null) == null;
        message = ''
          [mediNix/513] dns.ddns.tokenFile is rejected. Seal the token with
          systemd-creds and point acmeCredential / cloudflareTokenCredential
          at the .cred blob.
        '';
      }
      {
        assertion = zone != null;
        message = ''
          [mediNix/513] DDNS is enabled but neither dns.ddns.zone nor medinix.domain is set.
          Ref: ADR-513
        '';
      }
      {
        assertion = ddns.wanIp.provider != "command" || ddns.wanIp.command != null;
        message = "[mediNix/513] wanIp.provider = \"command\" requires wanIp.command != null.";
      }
      {
        assertion = !(ddns.wanIp.provider == "speedport") || hasReconnect;
        message = ''
          [mediNix/513] wanIp.provider = "speedport", aber kein Router-Adapter
          aktiv. Bitte 513-router-adapter-speedport.nix importieren.
        '';
      }
    ];

    # ── Drift-Check (alle ddns.interval) ──────────────────────────────────
    systemd.services.cloudflare-ddns = lib.mkMerge [
      ((import ../lib/service-factory.nix { inherit lib config pkgs; }) {
        name = "cloudflare-ddns";
        uid = cfUid;
        profile = "network";
        stateDir = cfStateDir;
        hardeningOnly = true;
        extraConfig = {
          Type = "oneshot";
          RuntimeDirectoryMode = "0700";
          NoExecPaths = [ "/" ];
          ExecPaths = [ "/nix/store" ];
        }
        // lib.optionalAttrs (credPath != null) {
          LoadCredentialEncrypted = [ "cf-ddns-token:${credPath}" ];
        }
        // lib.optionalAttrs (ddns.wanIp.provider == "speedport") (
          if ddns.wanIp.speedportPasswordCredential != null then {
            LoadCredentialEncrypted = [ "speedport-password:${ddns.wanIp.speedportPasswordCredential}" ];
          } else if ddns.wanIp.speedportPasswordFile != null then {
            LoadCredential = [ "speedport-password:${ddns.wanIp.speedportPasswordFile}" ];
          } else { }
        );
      })
      {
        description = "mediNix 513 DDNS — drift check";
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

        script = mkDdnsScript "check";

        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5min";
        };
      }
    ];

    # ── Zwangstrennung (05:00, nur mit Router-Adapter) ────────────────────
    systemd.services.cloudflare-ddns-reconnect = lib.mkIf hasReconnect (lib.mkMerge [
      ((import ../lib/service-factory.nix { inherit lib config pkgs; }) {
        name = "cloudflare-ddns-reconnect";
        uid = cfUid;
        profile = "network";
        stateDir = cfStateDir;
        hardeningOnly = true;
        extraConfig = {
          Type = "oneshot";
          RuntimeDirectoryMode = "0700";
          NoExecPaths = [ "/" ];
          ExecPaths = [ "/nix/store" ];
          # Kein Parallel-Check — sonst zwei CF-Calls mit evtl. verschiedenen IPs.
          Conflicts = [ "cloudflare-ddns.service" ];
        }
        // lib.optionalAttrs (credPath != null) {
          LoadCredentialEncrypted = [ "cf-ddns-token:${credPath}" ];
        }
        // (
          if ddns.wanIp.speedportPasswordCredential != null then {
            LoadCredentialEncrypted = [ "speedport-password:${ddns.wanIp.speedportPasswordCredential}" ];
          } else if ddns.wanIp.speedportPasswordFile != null then {
            LoadCredential = [ "speedport-password:${ddns.wanIp.speedportPasswordFile}" ];
          } else { }
        );
      })
      {
        description = "mediNix 513 DDNS — forced reconnect at 05:00";
        wantedBy = [ ]; # nur per Timer
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        path = [
          pkgs.curl
          pkgs.jq
          pkgs.iproute2
          pkgs.gawk
          pkgs.gnugrep
        ];

        script = mkDdnsScript "reconnect";

        unitConfig = {
          OnFailure = [ "alert-ntfy@%n.service" ];
        };

        serviceConfig = {
          # BEWUSST kein Restart: verhindert Doppel-Reconnect bei CF-Fehler.
          # Fehlschlag → ntfy (OnFailure). 4h-Check zieht IP später nach.
          Restart = "no";
          TimeoutStartSec = "180s";
        };
      }
    ]);

    # ── Timer ─────────────────────────────────────────────────────────────
    systemd.timers.cloudflare-ddns = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnUnitActiveSec = ddns.interval;
        OnBootSec = "5m";
        Persistent = true;
      };
    };

    systemd.timers.cloudflare-ddns-reconnect = lib.mkIf hasReconnect {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = ddns.reconnect.time;
        Persistent = false; # NICHT nachholen
        AccuracySec = "1s";
      };
    };

    # ── User/Group/StateDir ──────────────────────────────────────────────
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

    medinix.factoryUnits."cloudflare-ddns" = {
      uid = cfUid;
      stateDir = cfStateDir;
    };
  };
}
