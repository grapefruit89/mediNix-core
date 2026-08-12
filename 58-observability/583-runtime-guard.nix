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

  script = pkgs.writeShellApplication {
    name = "mediNix-runtime-guard";
    runtimeInputs = [ pkgs.iproute2 pkgs.nftables pkgs.curl pkgs.procps ];
    text = ''
      set -euo pipefail
      NTFY="${ntfy}"

      # 1. nftables-Regeln noch aktiv?
      if ! nft list ruleset 2>/dev/null | grep -q "mediNix-ingress"; then
        curl -s -d "RUNTIME ALERT: nftables mediNix-Regeln fehlen!" "$NTFY" || true
      fi

      # 2. Dienste binden auf 127.0.0.1 (nicht 0.0.0.0)?
      BAD=$(ss -tlnp 2>/dev/null | grep -E "0\.0\.0\.0:5[0-9]{3}" || true)
      if [ -n "$BAD" ]; then
        curl -s -d "RUNTIME ALERT: Dienst bindet auf 0.0.0.0! $BAD" "$NTFY" || true
      fi

      # 3. VPN-Interface UP wenn confinement aktiv?
      IFACE="${toString cfg.vpn.interface}"
      if [ -n "$IFACE" ] && ! ip link show "$IFACE" >/dev/null 2>&1; then
        curl -s -d "RUNTIME ALERT: VPN-Interface $IFACE DOWN!" "$NTFY" || true
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
