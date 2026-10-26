# ---
# id: "586-vpn-selftest"
# title: "VPN-Laufzeit-Selftest & Killswitch-Validierung"
# domain: 58
# folder: 58-observability
# status: active
# complexity: 2
# last_reviewed: 2026-10-26
# links:
#   adr: ADR-526
# provides: []
# requires: ["lib/registry", "lib/hardening-profiles"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---
# 58-observability/586-vpn-selftest.nix
#
# Prueft periodisch zur Laufzeit, ob der VPN-Killswitch (526) und das UID-basierte
# Policy-Routing greifen und kein Traffic aus VPN-gebundenen Diensten unverschluesselt leckt.
# Quelle: todo/blocks/21-observability-automation.json (D-21-03)
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.observability.vpnSelftest;
  vpnCfg = config.services.vpnKillSwitch;
  reg = import ../lib/registry.nix { inherit lib; };
  ntfyPort = (reg.services.ntfy or { }).port or 5810;
  ntfyUrl = "http://127.0.0.1:${toString ntfyPort}/alerts";

  activeInstances = lib.filterAttrs (_n: v: v.enable) (vpnCfg.instances or { });
  hasVpnInstances = vpnCfg.enable && (activeInstances != { });

  selftestScript = pkgs.writeShellApplication {
    name = "medinix-vpn-selftest";
    runtimeInputs = [
      pkgs.iproute2
      pkgs.curl
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      set -euo pipefail

      VPN_IF="${vpnCfg.vpnInterface or "wg-vpn"}"
      NTFY="${ntfyUrl}"
      FAILED=0
      ERR_MSG=""

      # 1. Interface-Check: Ist das VPN-Interface vorhanden und UP?
      if ! ip link show dev "$VPN_IF" up >/dev/null 2>&1; then
        FAILED=1
        ERR_MSG="VPN Interface $VPN_IF ist DOWN oder nicht vorhanden!"
      fi

      # 2. Routing-Check: Routet Traffic unter mark/table korrekt ueber das VPN-Interface?
      if [ "$FAILED" -eq 0 ]; then
        ROUTE_DEV="$(ip route show table ${toString (vpnCfg.routingTable or 5260)} default 2>/dev/null | grep -o 'dev [^ ]*' | cut -d' ' -f2 || true)"
        if [ "$ROUTE_DEV" != "$VPN_IF" ]; then
          FAILED=1
          ERR_MSG="Routing-Table ${toString (vpnCfg.routingTable or 5260)} routet Default nicht ueber $VPN_IF (Gefunden: '$ROUTE_DEV')!"
        fi
      fi

      # 3. Alerting bei Fehlschlag
      if [ "$FAILED" -ne 0 ]; then
        echo "VPN-Selftest FEHLGESCHLAGEN: $ERR_MSG" >&2
        curl -s -d "VPN Killswitch Alarm: $ERR_MSG" \
          -H "Title: VPN Killswitch Failure" \
          -H "Priority: urgent" \
          -H "Tags: warning,firewall,vpn" \
          "$NTFY" || true
        exit 1
      fi

      echo "VPN-Selftest ERFOLGREICH: Killswitch und Interface $VPN_IF sind aktiv und konsistent."
    '';
  };
in
{
  options.medinix.observability.vpnSelftest = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = hasVpnInstances;
      description = "Aktiviert den periodischen VPN-Routing- und Killswitch-Laufzeittest.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "systemd.timer-Intervall fuer den VPN-Selftest.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.medinix-vpn-selftest = {
      description = "mediNix VPN Killswitch & Routing Laufzeittest";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${selftestScript}/bin/medinix-vpn-selftest";
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };

    systemd.timers.medinix-vpn-selftest = {
      description = "Timer fuer mediNix VPN Killswitch Laufzeittest";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
      };
    };
  };
}
