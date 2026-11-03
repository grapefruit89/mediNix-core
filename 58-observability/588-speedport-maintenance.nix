# ---
# id: "588-speedport-maintenance"
# title: "Speedport Smart 4 — Tägliche Zwangstrennung & Router-Maintenance"
# domain: 58
# folder: 58-observability
# status: active
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
# Verhindert das unkontrollierte Wandern der 24h-Trennung in die Feierabend-Prime-Time.
# Reißt keine bestehenden Sessions am Tag ab und triggert rein deklarativ cloudflare-ddns.
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
    elif [ -n "''${SPEEDPORT_PASSWORD_FILE:-}" ] && [ -r "$SPEEDPORT_PASSWORD_FILE" ]; then
      PASSWORD_FILE="$SPEEDPORT_PASSWORD_FILE"
    elif [ -r "/home/moritz/.secrets/speedport-password" ]; then
      PASSWORD_FILE="/home/moritz/.secrets/speedport-password"
    else
      echo "FATAL: Speedport password file not found or not readable." >&2
      exit 1
    fi

    echo "=== [Speedport Maintenance] Starte kontrollierte Zwangstrennung um $(date) ==="

    ${pythonEnv}/bin/python3 - "$ROUTER" "$PASSWORD_FILE" <<'PY'
import asyncio, sys, time
from pathlib import Path
from speedport import Speedport

async def main():
    router = sys.argv[1]
    pw = Path(sys.argv[2]).read_text().strip()

    async with Speedport(router, pw, pause_time=0) as sp:
        await sp.login()
        await sp.update_ip_data()
        old_ip = sp.public_ip_v4
        print(f"Alte WAN-IP vor Reconnect: {old_ip}")

        print("Sende Reconnect-Befehl an Router (Connect.json)...")
        await sp.reconnect()

        # Warte auf Neuaufbau des DSL/PPP-Tunnels (typisch 15-25s)
        print("Warte auf Reconnect...")
        for attempt in range(1, 10):
            await asyncio.sleep(4)
            try:
                await sp.update_ip_data()
                new_ip = sp.public_ip_v4
                if new_ip and new_ip != old_ip and not new_ip.startswith("0."):
                    print(f"Erfolgreich reconnectet nach ca. {attempt * 4}s! Neue WAN-IP: {new_ip}")
                    return
            except Exception as e:
                # Waehrend des Verbindungsaufbaus antwortet das IP-Modul evtl. noch nicht
                pass

        print("WARNUNG: Reconnect gesendet, neue IP konnte noch nicht bestaetigt werden.")

asyncio.run(main())
PY

    echo "=== [Speedport Maintenance] Reconnect abgeschlossen ==="
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
      example = "/home/moritz/.secrets/speedport-password";
      description = "Lokale Passwort-Datei (Fallback/Entwicklung).";
    };
  };

  config = lib.mkIf (config.medinix.enable && cfg.enable) {
    systemd.services.speedport-reconnect = {
      description = "Speedport Smart 4 Proactive Reconnect (05:00 Uhr Zwangstrennung)";
      wantedBy = [ ]; # Nur durch Timer getriggert

      # Nach erfolgreichem Reconnect sofort Cloudflare-DDNS triggern (rein deklarativ!)
      onSuccess = lib.optionals (config.services.caddy.enable or true) [ "cloudflare-ddns.service" ];

      environment = {
        SPEEDPORT_HOST = cfg.routerIp;
      } // lib.optionalAttrs (cfg.passwordFile != null) {
        SPEEDPORT_PASSWORD_FILE = cfg.passwordFile;
      };

      serviceConfig = lib.mkMerge [
        {
          Type = "oneshot";
          ExecStart = "${reconnectScript}";
          TimeoutStartSec = "90s";

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
          RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
          RestrictRealtime = true;
          CapabilityBoundingSet = "";
        }
        (lib.optionalAttrs (cfg.passwordCredential != null) {
          LoadCredentialEncrypted = [ "speedport-password:${cfg.passwordCredential}" ];
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
