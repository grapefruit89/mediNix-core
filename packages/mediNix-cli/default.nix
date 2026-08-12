# packages/mediNix-cli/default.nix
# mediNix-core Health CLI — generiert aus lib/registry.nix (Build-Zeit-Metadaten)
# Subcommands: check | repair | status | vpn | secrets | help
# Build-Zeit-Parameter: registryJson, mediaRoot, metadataDir, mediaDomain
{ pkgs, lib, registryJson, mediaRoot ? "/data/media", metadataDir ? "/data/metadata", mediaDomain ? "" }:

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
    findutils
  ];
  text = ''
    set -euo pipefail

    # Service-Metadaten (Build-Zeit aus Registry generiert)
    SERVICES_JSON='${registryJson}'

    # Tier-Pfade + Domain (Build-Zeit-Parameter, portabel)
    MEDIA_ROOT="${mediaRoot}"
    METADATA_DIR="${metadataDir}"
    DOMAIN="${mediaDomain}"

    # Fix 1: PROBLEMS-Counter über mktemp-Datei (Subshell-sicher)
    PROBLEMS_FILE=$(mktemp)
    echo "0" > "$PROBLEMS_FILE"
    add_problem() { echo $(($(cat "$PROBLEMS_FILE") + 1)) > "$PROBLEMS_FILE"; }

    cmd_check() {
      echo "[CHECK] Benutzer & UIDs"
      echo "$SERVICES_JSON" | jq -r 'to_entries[] | select(.value.uid != null) | "\(.key) \(.value.uid)"' | while read -r name uid; do
        if id "$name" >/dev/null 2>&1; then
          actual_uid=$(id -u "$name")
          if [ "$actual_uid" = "$uid" ]; then
            echo "  ✓ $name  uid=$actual_uid (korrekt)"
          else
            echo "  ✗ $name  uid=$actual_uid ERWARTET $uid"
            add_problem
          fi
        else
          echo "  ✗ $name  FEHLT (uid=$uid)"
          add_problem
        fi
      done

      echo ""
      echo "[CHECK] State-Directories"
      echo "$SERVICES_JSON" | jq -r 'to_entries[] | select(.value.uid != null) | "\(.key) \(.value.port) \(.value.uid)"' | while read -r name port uid; do
        dir="/var/lib/''${name}-''${port}"
        if [ -d "$dir" ]; then
          mode=$(stat -c "%a" "$dir")
          owner=$(stat -c "%U:%G" "$dir")
          if [ "$mode" = "750" ] && [ "$owner" = "''${name}:media" ]; then
            echo "  ✓ $dir  mode=$mode owner=$owner"
          else
            echo "  ✗ $dir  mode=$mode owner=$owner (erwartet 750 ''${name}:media)"
            add_problem
          fi
        else
          echo "  ✗ $dir  FEHLT"
          add_problem
        fi
      done

      echo ""
      echo "[CHECK] SQLite WAL-Modus"
      echo "$SERVICES_JSON" | jq -r 'to_entries[] | select(.value.uid != null) | "\(.key) \(.value.port)"' | while read -r name port; do
        dir="/var/lib/''${name}-''${port}"
        find "$dir" -name '*.db' -type f 2>/dev/null | while read -r db; do
          mode=$(sqlite3 "$db" "PRAGMA journal_mode;" 2>/dev/null || echo "error")
          if [ "$mode" = "wal" ]; then
            echo "  ✓ $db  journal_mode=wal"
          else
            echo "  ✗ $db  journal_mode=$mode (erwartet wal)"
            add_problem
          fi
        done
      done

      echo ""
      echo "[CHECK] Tier-Speicher"
      for path in "$MEDIA_ROOT" "$METADATA_DIR"; do
        if [ -d "$path" ]; then
          pct=$(df -h "$path" | awk 'NR==2 {print $5}' | tr -d '%')
          free=$(df -h "$path" | awk 'NR==2 {print $4}')
          if [ "''${pct:-0}" -lt 85 ]; then
            echo "  ✓ $path  $free frei ($pct% belegt)"
          elif [ "''${pct:-0}" -lt 95 ]; then
            echo "  ⚠ $path  $free frei ($pct% belegt) — bald voll"
          else
            echo "  ✗ $path  $free frei ($pct% belegt) — KRITISCH"
            add_problem
          fi
        fi
      done

      echo ""
      echo "[CHECK] Services"
      echo "$SERVICES_JSON" | jq -r 'to_entries[] | select(.value.uid != null) | "\(.key) \(.value.port)"' | while read -r name port; do
        unit="''${name}-''${port}.service"
        if systemctl is-active --quiet "$unit" 2>/dev/null; then
          echo "  ✓ $unit  active"
        else
          echo "  ✗ $unit  failed/inactive"
          add_problem
        fi
      done

      echo ""
      echo "[CHECK] VPN Killswitch"
      if [ -f /run/usenet-vpn-verify.cache ]; then
        age=$(( $(date +%s) - $(stat -c %Y /run/usenet-vpn-verify.cache) ))
        echo "  ✓ letzter Leak-Check vor ''${age}s"
      else
        echo "  ⚠ kein Leak-Check-Cache (Usenet-Confinement inaktiv?)"
      fi

      echo ""
      echo "[CHECK] Secrets"
      for keyfile in /run/secrets/*api-key /run/secrets/*api-key-file; do
        [ -e "$keyfile" ] || continue
        if [ -s "$keyfile" ]; then
          echo "  ✓ $keyfile  vorhanden, nicht leer"
        else
          echo "  ✗ $keyfile  LEER"
          add_problem
        fi
      done

      echo ""
      PROBLEMS=$(cat "$PROBLEMS_FILE")
      rm -f "$PROBLEMS_FILE"
      if [ "$PROBLEMS" -eq 0 ]; then
        echo "✅ Alle Checks bestanden."
        return 0
      else
        echo "❌ $PROBLEMS Problem(e) gefunden. Nutze 'medinix repair'."
        return 1
      fi
    }

    cmd_repair() {
      echo "=== medinix repair ==="
      echo "$SERVICES_JSON" | jq -r 'to_entries[] | select(.value.uid != null) | "\(.key) \(.value.port) \(.value.uid)"' | while read -r name port uid; do
        dir="/var/lib/''${name}-''${port}"
        if [ ! -d "$dir" ]; then
          echo "  → mkdir -p $dir"
          mkdir -p "$dir"
        fi
        echo "  → chown ''${name}:media $dir"
        chown -R "''${name}:media" "$dir"
        echo "  → chmod 0750 $dir"
        chmod 0750 "$dir"
        find "$dir" -name '*.db' -type f 2>/dev/null | while read -r db; do
          echo "  → sqlite3 $db PRAGMA journal_mode=WAL"
          sqlite3 "$db" "PRAGMA journal_mode=WAL; PRAGMA cache_size=-20000;" 2>/dev/null || true
        done
        unit="''${name}-''${port}.service"
        if ! systemctl is-active --quiet "$unit" 2>/dev/null; then
          echo "  → systemctl restart $unit"
          systemctl restart "$unit" 2>/dev/null || echo "    (fehlgeschlagen — manuell prüfen)"
        fi
      done
      echo ""
      echo "Repariert: State-Dirs, Permissions, SQLite WAL, Failed Services."
      echo "NICHT repariert (manuell): Secrets, VPN-Config, Hardware."
    }

    cmd_status() {
      echo "$SERVICES_JSON" | jq -r 'to_entries[] | select(.value.uid != null) | "\(.key) \(.value.port) \(.value.caddyClass)"' | while read -r name port cls; do
        unit="''${name}-''${port}.service"
        if systemctl is-active --quiet "$unit" 2>/dev/null; then
          state="● running"
          uptime=$(systemctl show "$unit" --property=ActiveEnterTimestamp --value 2>/dev/null | head -c 19)
        else
          state="✗ failed"
          uptime="restart?"
        fi
        # Fix 2: Domain aus Build-Parameter
        case "$cls" in
          stream|public)
            if [ -n "$DOMAIN" ]; then
              url="https://''${name}.$DOMAIN"
            else
              url="https://''${name}.<domain nicht gesetzt>"
            fi
            ;;
          internal) url="http://127.0.0.1:''${port} (LAN)" ;;
          *)       url="—" ;;
        esac
        printf "%-16s %-10s %-10s %s\n" "''${name}-''${port}" "$state" "$uptime" "$url"
      done
    }

    cmd_vpn() {
      echo "[VPN Killswitch]"
      iface=$(ip route show table all 2>/dev/null | grep -oE 'dev [a-z0-9]+' | grep -iE 'privado|wg|vpn' | head -1 | awk '{print $2}')
      if [ -n "$iface" ]; then
        echo "  Interface: $iface"
        if ip link show "$iface" >/dev/null 2>&1; then
          echo "  Status: UP"
        else
          echo "  Status: DOWN ❌"
        fi
      else
        echo "  Kein VPN-Interface gefunden (Usenet-Confinement inaktiv?)"
      fi
      echo ""
      echo "Manueller Leak-Test:"
      if [ -x /run/current-system/sw/bin/usenet-vpn-verify ]; then
        /run/current-system/sw/bin/usenet-vpn-verify || echo "  Leak erkannt!"
      fi
      if [ -f /run/usenet-vpn-verify.cache ]; then
        echo ""
        echo "Letzter Cache: $(stat -c %y /run/usenet-vpn-verify.cache)"
      fi
    }

    cmd_secrets() {
      echo "[Secrets]"
      for keyfile in /run/secrets/*api-key /run/secrets/*api-key-file; do
        [ -e "$keyfile" ] || continue
        if [ -s "$keyfile" ]; then
          echo "  ✓ $keyfile  ok"
        else
          echo "  ✗ $keyfile  leer/fehlt"
        fi
      done
      echo ""
      echo "(Inhalte werden aus Sicherheitsgründen NICHT angezeigt)"
    }

    case "''${1:-help}" in
      check)   cmd_check ;;
      repair)  cmd_repair ;;
      status)  cmd_status ;;
      vpn)     cmd_vpn ;;
      secrets) cmd_secrets ;;
      help|*) echo "Usage: medinix <command>"
              echo "  check    — Read-only Health-Check (exit 1 bei Problemen)"
              echo "  repair   — Repariert State-Dirs, Permissions, WAL, Failed Services"
              echo "  status   — Schneller Überblick pro Dienst"
              echo "  vpn      — VPN Killswitch Status + Leak-Test"
              echo "  secrets  — Secret-Pfade prüfen (keine Inhalte)" ;;
    esac
  '';
}
