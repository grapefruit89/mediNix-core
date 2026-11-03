# ---
# id: "wan-ip-provider"
# title: "Modulare WAN-IP-Ermittlung (host, external, command)"
# domain: 51
# folder: "lib"
# status: active
# complexity: 1
# last_reviewed: 2026-10-25
# links:
#   adr: ADR-513
# ---
{ lib, pkgs ? null }:
rec {
  mkWanIpProvider =
    {
      provider ? "external",
      command ? null,
      pkgs ? pkgs,
    }:
    if provider == "external" then
      ''
        # RT-4: third-party echo services are a trusted NETWORK, not trusted
        # DATA. Any 200-body (error page, captive portal, garbage) must never
        # reach the Cloudflare API — validate the format before using it.
        WAN_IP=""
        for url in https://ifconfig.me https://api.ipify.org; do
          candidate=$(curl -s4 --fail-with-body "$url" || true)
          if printf '%s' "$candidate" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
            WAN_IP="$candidate"
            break
          fi
          echo "  WAN IP via $url unusable: '$(printf '%s' "$candidate" | head -c 40)'" >&2
        done
        if [ -z "$WAN_IP" ]; then
          echo "FATAL: Could not determine WAN IP." >&2
          exit 1
        fi
      ''
    else if provider == "host" then
      ''
        # host provider: returns default gateway. Real WAN-IP comes from router-specific provider (T-26 speedport).
        ROUTER=$(ip -4 route show default 2>/dev/null | awk 'NR==1 {print $3}')
        if [ -z "$ROUTER" ]; then
          ROUTER=$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oP '(?<=via )\S+' | head -n1)
        fi
        if [ -z "$ROUTER" ]; then
          echo "FATAL: Could not determine default gateway." >&2
          exit 1
        fi
        if ! printf '%s' "$ROUTER" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
          echo "FATAL: Router IP is not a valid IPv4: '$ROUTER'" >&2
          exit 1
        fi
        WAN_IP="$ROUTER"
      ''
    else if provider == "command" then
      ''
        ${lib.optionalString (command != null) command}
        if [ -z "''${WAN_IP:-}" ]; then
          echo "FATAL: Custom command did not set WAN_IP." >&2
          exit 1
        fi
      ''
    else if provider == "speedport" then
      let
        speedportApi = pkgs.callPackage ./speedport-api.nix { };
        pythonEnv = pkgs.python312.withPackages (_: [ speedportApi ]);
      in
      ''
        # speedport: WAN-IP via Speedport API (Python 3.12, public_ip_v4 synchron)
        ROUTER=$(ip -4 route show default 2>/dev/null | awk 'NR==1 {print $3}')
        if [ -z "$ROUTER" ]; then
          ROUTER=$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oP '(?<=via )\S+' | head -n1)
        fi
        if [ -z "$ROUTER" ]; then
          echo "FATAL: Could not determine default gateway." >&2
          exit 1
        fi
        if [ -n "''${CREDENTIALS_DIRECTORY:-}" ] && [ -r "$CREDENTIALS_DIRECTORY/speedport-password" ]; then
          PASSWORD_FILE="$CREDENTIALS_DIRECTORY/speedport-password"
        elif [ -n "''${SPEEDPORT_PASSWORD_FILE:-}" ] && [ -r "$SPEEDPORT_PASSWORD_FILE" ]; then
          PASSWORD_FILE="$SPEEDPORT_PASSWORD_FILE"
        elif [ -r "/home/moritz/.secrets/speedport-password" ]; then
          PASSWORD_FILE="/home/moritz/.secrets/speedport-password"
        else
          echo "FATAL: Speedport password file not found or not readable." >&2
          exit 1
        fi
        WAN_IP=$(${pythonEnv}/bin/python3 - "$ROUTER" "$PASSWORD_FILE" <<'PY'
import asyncio, sys
from pathlib import Path
from speedport import Speedport

async def main():
    router, pw_file = sys.argv[1], Path(sys.argv[2])
    pw = pw_file.read_text().strip()
    async with Speedport(router, pw, pause_time=0) as sp:
        await sp.login()
        await sp.update_ip_data()
        print(sp.public_ip_v4)

asyncio.run(main())
PY
)
        if [ -z "$WAN_IP" ]; then
          echo "FATAL: Could not determine WAN IP from Speedport." >&2
          exit 1
        fi
        if ! printf '%s' "$WAN_IP" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
          echo "FATAL: Speedport WAN IP is not a valid IPv4: '$WAN_IP'" >&2
          exit 1
        fi
      ''
    else
      throw "Unknown WAN-IP provider: ${provider}";
}
