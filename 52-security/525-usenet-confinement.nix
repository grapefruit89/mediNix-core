# ---
# id: "525-usenet-confinement"
# title: "Usenet VPN Confinement — UID-routed WireGuard isolation (no netns)"
# domain: 52
# folder: 52-security
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5410
#   skill: nixos-context7-gate
#   ref: "Nix-Grok modules/10-network/1096-vpn.nix (UID-routing statt netns, true IP leak check)"
# context7:
#   - query: "systemd.services serviceConfig RestrictNetworkInterfaces BindReadOnlyPaths example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "RestrictNetworkInterfaces + BindReadOnlyPaths valid serviceConfig keys"
# ---
# Usenet-Confinement: SABnzbd (5410) + Prowlarr (5360) werden NICHT in ein
# Network-Namespace gesperrt. Stattdessen nutzen wir UID-basiertes Routing:
# der Host (systemd-networkd routeTables oder wg-quick) routet alle Pakete
# dieser UIDs durch die VPN-Tabelle. Kein Port-Mapping, kein ns-Overhead,
# Loopback zwischen Arr-Stack funktioniert weiter (127.0.0.1 erreichbar).
#
# sandboxAttrs wird per mkMerge direkt auf die Units gelegt (KEIN Lesen aus
# config.systemd.services.* — das würde Infinite Recursion auslösen).
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  vpnIf = cfg.vpn.interface;
  resolvFile = "/etc/mediNix-resolv.conf";

  # sandboxAttrs: pro Service-Unit angehängt via mkMerge (nicht recursiveUpdate aus config)
  sandboxAttrs = {
    serviceConfig = {
      RestrictNetworkInterfaces = [ "lo" vpnIf ];
      BindReadOnlyPaths = [ "${resolvFile}:/etc/resolv.conf" ];
      PrivateIPC         = true;
      InaccessiblePaths  = [ "/sys/class/net" ];
    };
  };
in lib.mkIf (cfg.usenet-confinement.enable && vpnIf != "") {
  # Eigene DNS-Config mit VPN-DNS (verhindert Leaks auf Host-resolv.conf)
  environment.etc."mediNix-resolv.conf" = {
    text = lib.concatStringsSep "\n" (
      map (ns: "nameserver ${ns}") cfg.vpn.dnsServers
    ) + "\n";
  };

  # BUG 1 FIX: Kein Lesen aus config.systemd.services (vermeidet Infinite Recursion).
  # Stattdessen direkt per mkIf + mkMerge auf sabnzbd & prowlarr anwenden.
  systemd.services.sabnzbd = lib.mkIf config.services.sabnzbd.enable (lib.mkMerge [ sandboxAttrs ]);
  systemd.services.prowlarr = lib.mkIf config.services.prowlarr.enable (lib.mkMerge [ sandboxAttrs ]);

  # Echtes Leak-Monitoring: watchdog auf carrier + operstate des VPN-Interfaces
  # Feuert bei Interface-Änderung → verify-Skript prüft Routing-Tabelle
  systemd.paths."usenet-vpn-carrier" = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "/sys/class/net/${vpnIf}/carrier";
      Unit       = "usenet-vpn-verify.service";
    };
  };
  systemd.paths."usenet-vpn-operstate" = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "/sys/class/net/${vpnIf}/operstate";
      Unit       = "usenet-vpn-verify.service";
    };
  };

  systemd.services."usenet-vpn-verify" = {
    description = "Verify Usenet VPN routing (true IP leak check)";
    serviceConfig = {
      Type            = "oneshot";
      User            = "root";
      RuntimeMaxSec   = 60;
      Restart        = "no";
    };
    path = [ pkgs.iproute2 pkgs.curl pkgs.gnugrep pkgs.util-linux pkgs.systemd ];
    script = ''
      set -euo pipefail
      IFACE="${vpnIf}"

      # Caching / Lock gegen Thundering Herd
      exec 9>/run/usenet-vpn-verify.lock
      flock -n 9 || exit 0

      # Cache-Check (60s)
      CACHE_FILE="/run/usenet-vpn-verify.cache"
      if [ -f "$CACHE_FILE" ] && [ $(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") )) -lt 60 ]; then
        exit 0
      fi

      # BUG 2 FIX: Echter IP-Vergleich (Host vs VPN-Interface)
      HOST_IP=$(curl -fsS --max-time 10 https://api.ipify.org | tr -d '[:space:]' || echo "")
      VPN_IP=$(curl -fsS --max-time 10 --interface "$IFACE" https://api.ipify.org | tr -d '[:space:]' || echo "")

      if [ -n "$HOST_IP" ] && [ -n "$VPN_IP" ] && [ "$HOST_IP" = "$VPN_IP" ]; then
        echo "LEAK DETECTED: host=$HOST_IP equals vpn=$VPN_IP! Stopping Usenet stack." >&2
        systemctl stop sabnzbd prowlarr 2>/dev/null || true
        exit 1
      fi

      touch "$CACHE_FILE"
      echo "Usenet VPN IP leak check OK (Host=$HOST_IP, VPN=$VPN_IP)"
    '';
  };

  # Assertion: wenn confinement aktiv, muss das VPN-Interface vom Host da sein
  assertions = [ {
    assertion = cfg.usenet-confinement.enable -> (vpnIf != "");
    message = "usenet-confinement.enable erfordert vpn.interface (Host-WireGuard).";
  } ];
}
