# mediNix Health CLI — registry unitName is the systemd unit.
{ pkgs, lib, registryJson, mediaRoot ? "/data/media", metadataDir ? "/data/metadata", mediaDomain ? "" }:

let
  effectiveDomain = if mediaDomain != null then mediaDomain else "";
in
pkgs.writeShellApplication {
  name = "medinix";
  runtimeInputs = with pkgs; [
    systemd iproute2 sqlite curl jq coreutils util-linux gawk findutils
  ];
  text = ''
    set -euo pipefail
    SERVICES_JSON='${registryJson}'
    MEDIA_ROOT="${mediaRoot}"
    METADATA_DIR="${metadataDir}"
    DOMAIN="${effectiveDomain}"
    PROBLEMS_FILE=$(mktemp)
    echo "0" > "$PROBLEMS_FILE"
    add_problem() { echo $(($(cat "$PROBLEMS_FILE") + 1)) > "$PROBLEMS_FILE"; }
    cmd=help
    if [ "$#" -ge 1 ]; then cmd="$1"; fi

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

    if [ "$cmd" = check ]; then cmd_check
    elif [ "$cmd" = repair ]; then cmd_repair
    elif [ "$cmd" = status ]; then cmd_status
    elif [ "$cmd" = vpn ]; then cmd_vpn
    elif [ "$cmd" = secrets ]; then cmd_secrets
    else echo "Usage: medinix check|repair|status|vpn|secrets"
    fi
  '';
}
