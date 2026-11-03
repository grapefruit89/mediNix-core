# ---
# id: "513-router-adapter-speedport"
# title: "Speedport Smart 4 — Router-Adapter für 513-ddns"
# domain: 51
# folder: 51-ingress
# status: active
# complexity: 2
# last_reviewed: 2026-11-03
# provides: ["router-adapter-speedport"]
# requires: ["513-ddns"]
# upstream_docs: ["https://github.com/Andre0512/speedport-api"]
# adr: ADR-513
# links:
#   adr: ADR-513
# ---
# Reiner Hardware-Übersetzer. Weiß NICHTS über Cloudflare, DNS-Records oder
# Timer — das ist Aufgabe von 513-ddns.nix.
#
# Vertrag:
#   routerScripts.check     → stdout = aktuelle WAN-IPv4, exit 0/1
#   routerScripts.reconnect → stdout = neue WAN-IPv4, exit 0/1
#
# Beide Aktionen laufen in EINER Login-Session via speedport-api.
# Kein Dauerpolling, keine Retry-Schleife mit neuen Logins.
# Login-Budget: 1 pro Aufruf.
#
# Reconnect-Ablauf (EIN Login):
#   sp.login() → alte IP + Uptime lesen → sp.reconnect()
#   → 25s asyncio.sleep (15s Reset + 10s Puffer)
#   → bis zu 3× Status-Read (gleiche Session, KEIN neuer Login)
#   → Erfolg = Uptime hat sich geändert → neue IP auf stdout
#   → Fehlschlag = exit 1 → OnFailure → ntfy
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.medinix;
  ddns = cfg.dns.ddns;

  speedportPkg = pkgs.callPackage ../lib/speedport-api.nix { };
  pythonEnv = pkgs.python312.withPackages (_: [ speedportPkg ]);

  speedportClient = pkgs.writeText "speedport-client.py" ''
    import asyncio
    import sys
    from pathlib import Path
    from speedport import Speedport
    from speedport.exceptions import LoginPausedError, LoginException

    async def main():
        if len(sys.argv) != 4:
            print("usage: speedport-adapter <check|reconnect> <host> <pw-file>", file=sys.stderr)
            sys.exit(2)

        action, router, pw_file = sys.argv[1], sys.argv[2], Path(sys.argv[3])
        try:
            pw = pw_file.read_text().strip()
        except Exception as e:
            print(f"FATAL: cannot read password file {pw_file}: {e}", file=sys.stderr)
            sys.exit(1)

        async with Speedport(router, pw, pause_time=0) as sp:
            try:
                await sp.login()
            except LoginPausedError as e:
                print(f"FATAL: Speedport Login gesperrt (pause_time aktiv): {e}", file=sys.stderr)
                sys.exit(1)
            except LoginException as e:
                print(f"FATAL: Speedport Login fehlgeschlagen: {e}", file=sys.stderr)
                sys.exit(1)

            # Workaround gegen suppress(LoginPausedError): direkt sp.api.get_ip_data()
            sp._ip_data = await sp.api.get_ip_data()
            await sp.update_status()

            if action == "check":
                ip = sp.public_ip_v4
                if not ip or ip.startswith("0."):
                    print(f"FATAL: empty or invalid WAN-IPv4 from Speedport: '{ip}'", file=sys.stderr)
                    sys.exit(1)
                print(ip)
                return

            if action == "reconnect":
                old_ip = sp.public_ip_v4
                old_up = sp.inet_uptime
                print(f"Status vor Reconnect: WAN-IPv4={old_ip}, Uptime={old_up}", file=sys.stderr)

                print("Sende Reconnect-Befehl (Connect.json)...", file=sys.stderr)
                await sp.reconnect()

                print("Warte 25s Puffer fuer Leitungs-Reset...", file=sys.stderr)
                await asyncio.sleep(25)

                for attempt in range(1, 4):
                    try:
                        sp._ip_data = await sp.api.get_ip_data()
                        await sp.update_status()
                        new_ip = sp.public_ip_v4
                        new_up = sp.inet_uptime
                        if new_up != old_up and new_ip and not new_ip.startswith("0."):
                            if new_ip == old_ip:
                                print(f"WARN: Reconnect erfolgreich (Uptime geaendert), aber ISP vergab gleiche IP: {new_ip}", file=sys.stderr)
                            else:
                                print(f"Reconnect erfolgreich bestaetigt: neue IP={new_ip}, Uptime={new_up} (vorher {old_up})", file=sys.stderr)
                            print(new_ip)
                            return
                        print(f"Versuch {attempt}/3: Uptime noch unveraendert ({new_up}), warte 20s...", file=sys.stderr)
                    except Exception as e:
                        print(f"Versuch {attempt}/3: Ausnahme beim Status-Lesen: {type(e).__name__}: {e}", file=sys.stderr)
                    if attempt < 3:
                        await asyncio.sleep(20)

                print("FATAL: Reconnect konnte innerhalb des Zeitfensters nicht bestaetigt werden.", file=sys.stderr)
                sys.exit(1)

            print(f"Unbekannte Aktion: {action}", file=sys.stderr)
            sys.exit(2)

    asyncio.run(main())
  '';

  readPw = ''
    if [ -n "''${CREDENTIALS_DIRECTORY:-}" ] && [ -r "$CREDENTIALS_DIRECTORY/speedport-password" ]; then
      PW_FILE="$CREDENTIALS_DIRECTORY/speedport-password"
    elif [ -n "''${SPEEDPORT_PASSWORD_FILE:-}" ] && [ -r "$SPEEDPORT_PASSWORD_FILE" ]; then
      PW_FILE="$SPEEDPORT_PASSWORD_FILE"
    elif [ -r "/home/moritz/.secrets/speedport-password" ]; then
      PW_FILE="/home/moritz/.secrets/speedport-password"
    else
      echo "FATAL: speedport password not found (neither in credentials directory nor SPEEDPORT_PASSWORD_FILE)" >&2
      exit 1
    fi
  '';

in
{
  config = lib.mkIf (
    cfg.enable
    && cfg.dns.mode == "standalone"
    && ddns.enable
    && ddns.wanIp.provider == "speedport"
  ) {
    medinix._internal.ddns.routerScripts = {
      check = pkgs.writeShellScript "speedport-check" ''
        set -euo pipefail
        ${readPw}
        ROUTER="''${SPEEDPORT_HOST:-${ddns.wanIp.routerIp or "192.168.2.1"}}"
        if [ -z "$ROUTER" ]; then
          ROUTER=$(ip -4 route show default 2>/dev/null | awk 'NR==1 {print $3}')
        fi
        [ -n "$ROUTER" ] || { echo "FATAL: no router IP or default route" >&2; exit 1; }
        exec ${pythonEnv}/bin/python3 ${speedportClient} check "$ROUTER" "$PW_FILE"
      '';

      reconnect = pkgs.writeShellScript "speedport-reconnect" ''
        set -euo pipefail
        ${readPw}
        ROUTER="''${SPEEDPORT_HOST:-${ddns.wanIp.routerIp or "192.168.2.1"}}"
        if [ -z "$ROUTER" ]; then
          ROUTER=$(ip -4 route show default 2>/dev/null | awk 'NR==1 {print $3}')
        fi
        [ -n "$ROUTER" ] || { echo "FATAL: no router IP or default route" >&2; exit 1; }
        exec ${pythonEnv}/bin/python3 ${speedportClient} reconnect "$ROUTER" "$PW_FILE"
      '';
    };
  };
}
