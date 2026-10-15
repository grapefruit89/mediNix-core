# ---
# id: "cli"
# title: "mediNix Health-CLI + Triage (aus der Registry generiert)"
# domain: 50
# folder: "lib"
# status: active
# complexity: 3
# last_reviewed: 2026-10-15
# links:
#   adr: ADR-0000
# ---
# mediNix Health CLI — registry unitName is the systemd unit.
# ids/show/logs/triage: Ist-Zustand (IDs, Ports, Pfade, Rechte, Logs) in EINEM Aufruf.
# triage <symptom> arbeitet die Kette aus lib/runbook.json ab (SSoT; docs/RUNBOOK.md §5 generiert).
{
  pkgs,
  lib,
  registryJson,
  mediaRoot ? "/data/media",
  metadataDir ? "/data/metadata",
  mediaDomain ? "",
  ...
}:

let
  effectiveDomain = if mediaDomain != null then mediaDomain else "";

  # Runbook = SSoT: lib/runbook.json. EINE Quelle — das CLI liest sie direkt,
  # docs/RUNBOOK.md §5 wird daraus generiert (scripts/gen_runbook.py).
  runbookJson = builtins.readFile ./runbook.json;
in
pkgs.writeShellApplication {
  name = "medinix";
  runtimeInputs = with pkgs; [
    systemd
    iproute2
    sqlite
    curl
    jq
    coreutils
    util-linux
    gawk
    gnugrep
    gnused
    findutils
  ];
  text = ''
    set -euo pipefail
    SERVICES_JSON='${registryJson}'
    RUNBOOK_JSON='${runbookJson}'
    export MEDIA_ROOT="${mediaRoot}"
    export METADATA_DIR="${metadataDir}"
    DOMAIN="${effectiveDomain}"

    PROBLEMS_FILE=$(mktemp)
    echo "0" > "$PROBLEMS_FILE"
    add_problem() { echo $(($(cat "$PROBLEMS_FILE") + 1)) > "$PROBLEMS_FILE"; }

    unit_of() { echo "$SERVICES_JSON" | jq -r --arg k "$1" '.[$k].unitName // $1'; }

    # Bereich (50..59) ODER Servicename -> Registry-Keys (eine pro Zeile)
    keys_for() {
      local sel="''${1:-}"
      if [ -z "$sel" ]; then
        echo "$SERVICES_JSON" | jq -r 'keys[]'
      elif printf '%s' "$sel" | grep -qE '^[0-9]{2}$'; then
        echo "$SERVICES_JSON" | jq -r --arg d "$sel" 'to_entries[] | select(((.value.num|tostring)[0:2])==$d) | .key'
      else
        echo "$SERVICES_JSON" | jq -r --arg n "$sel" 'to_entries[] | select(.key==$n) | .key'
      fi
    }

    # ── ids: Ist-IDs/Pfade/Rechte eines Bereichs (DER eine Befehl) ────────
    cmd_ids() {
      local sel="''${1:-}"
      local k unit port uid gid sd mode
      printf '%-20s %-6s %-12s %-28s %s\n' UNIT PORT UID:GID STATE-DIR MODE
      while read -r k; do
        [ -z "$k" ] && continue
        unit=$(echo "$SERVICES_JSON" | jq -r --arg k "$k" '.[$k].unitName // $k')
        port=$(echo "$SERVICES_JSON" | jq -r --arg k "$k" '.[$k].port // "-"')
        uid=$(echo "$SERVICES_JSON" | jq -r --arg k "$k" '.[$k].uid // "-"')
        gid=$(echo "$SERVICES_JSON" | jq -r --arg k "$k" '.[$k].sharedGid // "-"')
        sd=$(echo "$SERVICES_JSON" | jq -r --arg k "$k" '.[$k].stateDir // "-"')
        mode="-"
        if [ "$sd" != "-" ] && [ -d "$sd" ]; then mode=$(stat -c '%a %U:%G' "$sd" 2>/dev/null || echo "?"); fi
        printf '%-20s %-6s %-12s %-28s %s\n' "$unit" "$port" "''${uid}:''${gid}" "$sd" "$mode"
      done < <(keys_for "$sel")
    }

    # ── show: ein Dienst, volle Fakten + letzte Logs ──────────────────────
    cmd_show() {
      local svc="''${1:-}"
      [ -z "$svc" ] && { echo "usage: medinix show <service>" >&2; return 2; }
      local unit port sd
      unit=$(unit_of "$svc")
      port=$(echo "$SERVICES_JSON" | jq -r --arg k "$svc" '.[$k].port // empty')
      sd=$(echo "$SERVICES_JSON" | jq -r --arg k "$svc" '.[$k].stateDir // empty')
      echo "### $svc (unit=$unit)"
      systemctl show "$unit.service" --no-pager \
        -p ActiveState -p SubState -p MainPID -p User -p Group -p StateDirectory -p ExecMainStartTimestamp \
        2>/dev/null || echo "  (unit $unit.service nicht gefunden)"
      if [ -n "$port" ]; then
        echo "  socket: $(ss -H -ltn "sport = :$port" 2>/dev/null || echo "nichts auf Port $port")"
      fi
      if [ -n "$sd" ] && [ -e "$sd" ]; then
        echo "  state:  $sd  $(stat -c '%a %U:%G' "$sd" 2>/dev/null || echo '?')"
      fi
      echo "  --- logs (30) ---"
      journalctl -u "$unit.service" -n 30 --no-pager 2>/dev/null || true
      echo
    }

    # ── logs: journald-Abfrage eines Dienstes ─────────────────────────────
    cmd_logs() {
      local svc="''${1:-}" n="''${2:-50}"
      [ -z "$svc" ] && { echo "usage: medinix logs <service> [lines]" >&2; return 2; }
      journalctl -u "$(unit_of "$svc").service" -n "$n" --no-pager
    }

    # ── triage: Bereich | Service | Symptom (Runbook-Kette) ───────────────
    cmd_triage() {
      local sel="''${1:-}"
      [ -z "$sel" ] && { echo "usage: medinix triage <bereich|service|symptom>" >&2; return 2; }
      if printf '%s' "$sel" | grep -qE '^[0-9]{2}$'; then
        echo "== Bereich $sel: IDs =="
        cmd_ids "$sel"
        echo "== Status =="
        local k u
        while read -r k; do
          [ -z "$k" ] && continue
          u=$(unit_of "$k")
          if systemctl is-active --quiet "$u.service" 2>/dev/null; then echo "  ok   $u"; else echo "  DOWN $u"; fi
        done < <(keys_for "$sel")
        return 0
      fi
      if echo "$SERVICES_JSON" | jq -e --arg k "$sel" 'has($k)' >/dev/null 2>&1; then
        cmd_show "$sel"
        return 0
      fi
      local entry
      entry=$(echo "$RUNBOOK_JSON" | jq -c --arg s "$sel" '.[$s] // empty')
      if [ -z "$entry" ]; then
        echo "unbekannt: $sel" >&2
        echo "Bereiche 50..59 | Services (siehe 'medinix ids') | Symptome:" >&2
        echo "$RUNBOOK_JSON" | jq -r 'keys[]' | sed 's/^/  /' >&2
        return 2
      fi
      echo "== Symptom: $sel =="
      echo "$entry" | jq -r '"fix: " + (.fix // "")'
      local svc p
      while read -r svc; do [ -z "$svc" ] && continue; cmd_show "$svc"; done < <(echo "$entry" | jq -r '.chain[]?')
      while read -r p; do [ -z "$p" ] && continue; echo "path $p -> $(stat -c '%a %U:%G' "$p" 2>/dev/null || echo MISSING)"; done < <(echo "$entry" | jq -r '.paths[]?')
    }

    cmd_check() {
      echo "[CHECK] Services"
      echo "$SERVICES_JSON" | jq -r 'to_entries[] | select(.value.uid != null) | .value.unitName // .key' | while read -r unit; do
        if systemctl is-active --quiet "$unit.service" 2>/dev/null; then
          echo "  ok $unit.service"
        else
          echo "  FAIL $unit.service"
          add_problem
        fi
      done
      echo ""
      echo "[CHECK] Secrets"
      if ls /var/lib/medinix/secrets/*.encrypted >/dev/null 2>&1; then
        ls /var/lib/medinix/secrets/*.encrypted
      else
        echo "  no blobs in /var/lib/medinix/secrets"
      fi
      echo ""
      PROBLEMS=$(cat "$PROBLEMS_FILE")
      rm -f "$PROBLEMS_FILE"
      if [ "$PROBLEMS" -eq 0 ]; then
        echo "ok"
        return 0
      else
        echo "$PROBLEMS problem(s)"
        return 1
      fi
    }

    cmd_repair() {
      echo "$SERVICES_JSON" | jq -r 'to_entries[] | select(.value.uid != null) | .value.unitName // .key' | while read -r unit; do
        if ! systemctl is-active --quiet "$unit.service" 2>/dev/null; then
          systemctl restart "$unit.service" 2>/dev/null || echo "restart failed: $unit"
        fi
      done
    }

    cmd_status() {
      echo "$SERVICES_JSON" | jq -r 'to_entries[] | select(.value.uid != null) | "\(.key) \(.value.unitName // .key) \(.value.port) \(.value.caddyClass)"' | while read -r name unit port cls; do
        if systemctl is-active --quiet "$unit.service" 2>/dev/null; then
          state="running"
        else
          state="failed"
        fi
        case "$cls" in
          stream|public|idp)
            if [ -n "$DOMAIN" ]; then url="https://$name.$DOMAIN"; else url="http://$name.local"; fi ;;
          internal) url="http://127.0.0.1:$port" ;;
          *) url="-" ;;
        esac
        printf "%-16s %-10s %s\n" "$unit" "$state" "$url"
      done
    }

    cmd_vpn() {
      ip -brief link | grep -E 'wg|vpn' || echo "no wg interface"
    }

    cmd_secrets() {
      ls -l /var/lib/medinix/secrets/*.encrypted 2>/dev/null || echo "none"
    }

    cmd=help
    if [ "$#" -ge 1 ]; then cmd="$1"; shift; fi

    if [ "$cmd" = check ]; then cmd_check
    elif [ "$cmd" = repair ]; then cmd_repair
    elif [ "$cmd" = status ]; then cmd_status
    elif [ "$cmd" = vpn ]; then cmd_vpn
    elif [ "$cmd" = secrets ]; then cmd_secrets
    elif [ "$cmd" = ids ]; then cmd_ids "''${1:-}"
    elif [ "$cmd" = show ]; then cmd_show "''${1:-}"
    elif [ "$cmd" = logs ]; then cmd_logs "''${1:-}" "''${2:-50}"
    elif [ "$cmd" = triage ]; then cmd_triage "''${1:-}"
    else echo "Usage: medinix {ids [bereich]|show <svc>|logs <svc> [n]|triage <bereich|svc|symptom>|check|repair|status|vpn|secrets}"
    fi
  '';
}
