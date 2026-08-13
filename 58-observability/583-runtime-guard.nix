# ---
# id: "583-runtime-guard"
# title: "Runtime-Guard — stündlicher Check der laufenden Maschine (nftables/0.0.0.0/VPN)"
# domain: 58
# folder: 58-observability
# status: active
# complexity: 3
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-0000 (Binding 127.0.0.1), ADR-5043
#   repo-harvest: mynixos-v5 (runtime-guard pattern)
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  ntfy = "http://127.0.0.1:5810/mediNix-runtime";

  registry = import ../lib/registry.nix { inherit lib; };
  # Hole alle Ports aus der Registry für den 0.0.0.0 Check
  portsList = lib.mapAttrsToList (_: svc: toString svc.port) (lib.filterAttrs (_: svc: svc.port != null) registry.services);
  portsRegex = lib.concatStringsSep "|" portsList;

  script = pkgs.writeShellApplication {
    name = "mediNix-runtime-guard";
    runtimeInputs = [ pkgs.iproute2 pkgs.nftables pkgs.curl pkgs.procps ];
    text = ''
      set -euo pipefail
      NTFY="${ntfy}"

      # 1. nftables-Regeln noch aktiv?
      if ! nft list ruleset 2>/dev/null | grep -q "mediNix-ingress"; then
        curl -s -d "RUNTIME ALERT: nftables mediNix-Regeln fehlen!" "$NTFY" || echo "NTFY Notification failed" >&2
      fi

      # 2. Dienste binden auf 127.0.0.1 (nicht 0.0.0.0)?
      BAD=$(ss -tlnp 2>/dev/null | grep -E "0\.0\.0\.0:(${portsRegex})\b" || true)
      if [ -n "$BAD" ]; then
        curl -s -d "RUNTIME ALERT: Dienst bindet auf 0.0.0.0! $BAD" "$NTFY" || echo "NTFY Notification failed" >&2
      fi

      # 3. VPN-Interface UP und Route aktiv, wenn confinement aktiv?
      IFACE="${toString cfg.vpn.interface}"
      if [ -n "$IFACE" ]; then
        if ! ip link show "$IFACE" >/dev/null 2>&1; then
          curl -s -d "RUNTIME ALERT: VPN-Interface $IFACE DOWN!" "$NTFY" || echo "NTFY Notification failed" >&2
        elif ! ip route show table all dev "$IFACE" | grep -q "default"; then
          curl -s -d "RUNTIME ALERT: VPN-Interface $IFACE UP, aber keine Default-Route aktiv!" "$NTFY" || echo "NTFY Notification failed" >&2
        fi
      fi

      echo "Runtime-Guard OK"
    '';
  };
in
lib.mkIf (cfg.enable && cfg.observability.runtimeGuard) {
  systemd.timers.mediNix-runtime-guard = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "hourly";
  };

  systemd.services.mediNix-runtime-guard = {
    serviceConfig = profiles.script // { Type = "oneshot"; };
    path = [ pkgs.iproute2 pkgs.nftables pkgs.curl pkgs.procps ];
    script = "${lib.getExe script}";
  };
}
