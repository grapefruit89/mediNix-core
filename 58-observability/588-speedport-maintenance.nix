# ---
# id: "588-speedport-maintenance"
# title: "Speedport Smart 4 — Tägliche Zwangstrennung & Router-Maintenance"
# domain: 58
# folder: 58-observability
# status: draft
# complexity: 2
# last_reviewed: 2026-11-03
# links:
#   adr: ADR-513
# provides: ["speedport-maintenance"]
# requires: ["513-cloudflare-dns"]
# ports: []
# upstream_docs: ["https://github.com/Andre0512/speedport-api"]
# forum_links: []
# upstream_github: "https://github.com/Andre0512/speedport-api"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---
# 58-observability/588-speedport-maintenance.nix
#
# Zwangstrennung um 05:00 Uhr morgens via Speedport-API (Connect.json reconnect).
# Reißt um 05:00 Uhr gezielt bestehende Sessions ab und setzt den 24h-Telekom-Timer zurueck,
# um unkontrollierte Zwangstrennungen waehrend des Tages / Feierabends zu verhindern.
# Triggert nach bestaetigter neuer Uptime rein deklarativ cloudflare-ddns.service.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.observability.speedportMaintenance;
  speedportPkg = pkgs.callPackage ../pkgs/speedport-api { };
  pythonEnv = pkgs.python312.withPackages (_: [ speedportPkg ]);

  reconnectScript = pkgs.writeShellScript "speedport-reconnect" ''
    set -euo pipefail

    ROUTER="''${SPEEDPORT_HOST:-192.168.2.1}"

    if [ -n "''${CREDENTIALS_DIRECTORY:-}" ] && [ -r "$CREDENTIALS_DIRECTORY/speedport-password" ]; then
      PASSWORD_FILE="$CREDENTIALS_DIRECTORY/speedport-password"
    else
      echo "FATAL: Speedport password credential ($CREDENTIALS_DIRECTORY/speedport-password) not found or not readable." >&2
      exit 1
    fi

    echo "=== [Speedport Maintenance] Starte kontrollierte Zwangstrennung um $(date) ==="

    ${pythonEnv}/bin/python3 - "$ROUTER" "$PASSWORD_FILE" <<'PY'
import asyncio, sys, time
from pathlib import Path
import aiohttp
from speedport import Speedport
from speedport.exceptions import LoginPausedError, LoginException

async def main():
    router = sys.argv[1]
    pw = Path(sys.argv[2]).read_text().strip()

    async with Speedport(router, pw, pause_time=0) as sp:
        try:
            await sp.login()
        except LoginPausedError as e:
            print(f"FATAL: Speedport Login gesperrt (pause_time aktiv): {e}", file=sys.stderr)
            sys.exit(1)
        except LoginException as e:
            print(f"FATAL: Speedport Login fehlgeschlagen: {e}", file=sys.stderr)
            sys.exit(1)

        await sp.update_ip_data()
        old_ip = sp.public_ip_v4
        old_uptime = sp.inet_uptime
        print(f"Status vor Reconnect: WAN-IP={old_ip}, Verbindung aktiv seit={old_uptime}")

        print("Sende Reconnect-Befehl an Router (Connect.json)...")
        await sp.reconnect()

        # Warte auf Neuaufbau des DSL/PPP-Tunnels (typisch 12-25s)
        print("Warte auf Reconnect-Bestaetigung...")
        for attempt in range(1, 15):
            await asyncio.sleep(3)
            try:
                await sp.update_ip_data()
                new_ip = sp.public_ip_v4
                new_uptime = sp.inet_uptime
                # Erfolgskriterium: Uptime hat sich geaendert (Router hat neu verbunden) und valide IP liegt an
                if new_ip and not new_ip.startswith("0.") and new_uptime != old_uptime:
                    print(f"Erfolgreich reconnectet nach ca. {attempt * 3}s!")
                    print(f"Neue WAN-IP: {new_ip}, Neue Uptime: {new_uptime}")
                    return
            except (aiohttp.ClientError, asyncio.TimeoutError, ConnectionError, OSError):
                # Waehrend des Verbindungsaufbaus antwortet das IP-Modul evtl. noch nicht
                pass
            except Exception as e:
                print(f"Unerwarteter Fehler bei Statusabfrage waehrend Reconnect: {type(e).__name__}: {e}", file=sys.stderr)
                sys.exit(1)

        print("FEHLER: Reconnect konnte nicht bestaetigt werden (Uptime unveraendert oder keine gueltige IP).", file=sys.stderr)
        sys.exit(1)

asyncio.run(main())
PY

    echo "=== [Speedport Maintenance] Reconnect erfolgreich abgeschlossen ==="
  '';
in
{
  options.medinix.observability.speedportMaintenance = {
    enable = lib.mkEnableOption "Tägliche proaktive Speedport-Zwangstrennung um 05:00 Uhr morgens";
    time = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 05:00:00";
      description = "systemd OnCalendar Zeitangabe für die Zwangstrennung.";
    };
    routerIp = lib.mkOption {
      type = lib.types.str;
      default = "192.168.2.1";
      description = "LAN-IP des Speedport Smart 4 Routers.";
    };
    passwordCredential = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Pfad zum TPM-versiegelten Speedport-Passwort (.cred).";
    };
    passwordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/etc/nixos/secrets/speedport-password";
      description = "Pfad zur lokalen Passwort-Datei (wird via systemd LoadCredential als root bereitgestellt).";
    };
  };

  config = lib.mkIf (config.medinix.enable && cfg.enable) {
    systemd.services.speedport-reconnect = {
      description = "Speedport Smart 4 Proactive Reconnect (05:00 Uhr Zwangstrennung)";
      wantedBy = [ ]; # Nur durch Timer getriggert

      # Nach erfolgreichem Reconnect sofort Cloudflare-DDNS triggern (rein deklarativ via systemd)
      onSuccess = lib.optionals (config.medinix.dns.ddns.enable or false) [ "cloudflare-ddns.service" ];

      unitConfig = {
        OnFailure = [ "alert-ntfy@%n.service" ];
        StartLimitBurst = 2;
        StartLimitIntervalSec = "15min";
      };

      environment = {
        SPEEDPORT_HOST = cfg.routerIp;
      };

      serviceConfig = lib.mkMerge [
        {
          Type = "oneshot";
          ExecStart = "${reconnectScript}";
          TimeoutStartSec = "90s";

          # Begrenzter Retry: Warte 6 Minuten (Speedport LoginPaused-Sperre ist 5min)
          Restart = "on-failure";
          RestartSec = "6min";

          # Härtung: DynamicUser (kein permanenter User)
          DynamicUser = true;

          # eBPF Kernel-Netzwerksperre: Darf AUSSCHLIESSLICH mit dem Router sprechen!
          IPAddressDeny = [ "any" ];
          IPAddressAllow = [ cfg.routerIp ];

          # Sandbox & Isolation
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          MemoryDenyWriteExecute = true;
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
          LockPersonality = true;
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
          CapabilityBoundingSet = "";
        }
        (lib.optionalAttrs (cfg.passwordCredential != null) {
          LoadCredentialEncrypted = [ "speedport-password:${cfg.passwordCredential}" ];
        })
        (lib.optionalAttrs (cfg.passwordCredential == null && cfg.passwordFile != null) {
          LoadCredential = [ "speedport-password:${cfg.passwordFile}" ];
        })
      ];
    };

    systemd.timers.speedport-reconnect = {
      description = "Timer für tägliche Speedport-Zwangstrennung (05:00 Uhr)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.time;
        # Eiserne Regel: Persistent=false, damit verpasste Läufe NICHT abends beim Boot nachgeholt werden!
        Persistent = false;
        AccuracySec = "1s";
      };
    };
  };
}
