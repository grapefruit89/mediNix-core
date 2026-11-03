# ---
# id: "513-fritzbox-reconnect"
# title: "FRITZ!Box 7520 / OpenWrt — Geplante Zwangstrennung (Template / Inaktiv)"
# domain: 51
# folder: 51-ingress
# status: draft
# complexity: 1
# last_reviewed: 2026-11-03
# links:
#   adr: ADR-513
# provides: ["fritzbox-reconnect"]
# requires: ["513-cloudflare-dns"]
# ports: []
# upstream_docs: ["https://openwrt.org/docs/guide-user/base-system/ubus"]
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---
# 51-ingress/513-fritzbox-reconnect.nix
#
# ZUKUNFTS-TEMPLATE: Geplante Zwangstrennung um 05:00 Uhr morgens für FRITZ!Box 7520.
#
# Hintergrund & Einsatzzweck:
# - Die FRITZ!Box 7520 (IPQ4019 SoC) soll künftig mit OpenWrt als VDSL-Router
#   den bisherigen Speedport Smart 4 ablösen.
# - Dieses Companion-Modul zu 513-cloudflare-dns ist bereits vorbereitet, damit
#   beim Hardware-Tausch lediglich 513-speedport-reconnect deaktiviert/entfernt
#   und dieses Modul aktiviert werden muss (513-cloudflare-dns bleibt 100% unangetastet).
#
# Reconnect-Mechanismen je nach installierter Firmware:
# 1. OpenWrt (Geplanter Zielzustand):
#    Reconnect via ubus / SSH oder RPCD JSON-RPC:
#    `ubus call network.interface.wan down && sleep 3 && ubus call network.interface.wan up`
# 2. FritzOS (Original AVM):
#    Reconnect via TR-064 / UPnP-IGD SOAP:
#    SOAPAction: "urn:schemas-upnp-org:service:WANIPConnection:1#ForceTermination"
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.ingress.fritzboxReconnect;
in
{
  options.medinix.ingress.fritzboxReconnect = {
    enable = lib.mkEnableOption "Geplante tägliche Zwangstrennung für FRITZ!Box 7520 / OpenWrt (Template)";

    time = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 05:00:00 Europe/Berlin";
      description = "systemd OnCalendar Zeitangabe für die Zwangstrennung.";
    };

    routerIp = lib.mkOption {
      type = lib.types.str;
      default = "192.168.178.1";
      description = "LAN-IP des FRITZ!Box / OpenWrt Routers.";
    };

    mode = lib.mkOption {
      type = lib.types.enum [ "openwrt" "tr064" ];
      default = "openwrt";
      description = "Reconnect-Methode: 'openwrt' (via ubus/SSH) oder 'tr064' (AVM SOAP).";
    };

    sshKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "SSH-Key für OpenWrt ubus-Befehl (nur bei mode = 'openwrt').";
    };
  };

  # Standardmäßig inaktiv — wird erst scharfgeschaltet, wenn die 7520 im Netz hängt
  config = lib.mkIf (config.medinix.enable && cfg.enable) {
    assertions = [
      {
        assertion = !(config.medinix.ingress.speedportReconnect.enable or false);
        message = "[mediNix/513-fritzbox-reconnect] Es darf nicht gleichzeitig speedportReconnect und fritzboxReconnect aktiv sein.";
      }
    ];

    systemd.services.fritzbox-reconnect = {
      description = "FRITZ!Box 7520 / OpenWrt Proactive Reconnect (05:00 Uhr)";
      wantedBy = [ ];

      # Triggert nach Reconnect sofort Cloudflare-DDNS
      onSuccess = lib.optionals (config.systemd.services ? "cloudflare-ddns") [ "cloudflare-ddns.service" ];

      unitConfig = {
        OnFailure = [ "alert-ntfy@%n.service" ];
        StartLimitBurst = 2;
        StartLimitIntervalSec = "15min";
      };

      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "120s";
        Restart = "on-failure";
        RestartSec = "2min";
        DynamicUser = true;
        IPAddressDeny = [ "any" ];
        IPAddressAllow = [ cfg.routerIp ];
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;

        # Placeholder ExecStart — wird bei der finalen Inbetriebnahme mit OpenWrt ausprogrammiert
        ExecStart = "${pkgs.writeShellScript "fritzbox-reconnect-placeholder" ''
          echo "FRITZ!Box 7520 / OpenWrt Reconnect wird ausgeführt (${cfg.mode})..."
          # TODO: OpenWrt ubus call oder TR-064 SOAP-Call
        ''}";
      };
    };

    systemd.timers.fritzbox-reconnect = {
      description = "Timer für FRITZ!Box / OpenWrt Zwangstrennung (05:00 Uhr)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.time;
        Persistent = false;
        AccuracySec = "1s";
      };
    };
  };
}
