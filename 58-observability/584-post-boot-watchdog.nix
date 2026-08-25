# ---
# id: "584-post-boot-watchdog"
# title: "Post-Boot Watchdog — once 180s after boot: restart failed services"
# domain: 58
# folder: 58-observability
# status: active
# complexity: 2
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-0000, ADR-5043
#   repo-harvest: NixmitGROK (post-boot-watchdog pattern)
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  ntfyPort = (import ../lib/registry.nix { inherit lib; }).services.ntfy.port;
  ntfy = "http://127.0.0.1:${toString ntfyPort}/mediNix-boot";

  registry = import ../lib/registry.nix { inherit lib; };
  # All services from Registry (with and without Port)
  allUnits = lib.mapAttrsToList
    (_: svc: svc.unitName)
    registry.services;
  unitList = lib.concatStringsSep " " allUnits;

  script = pkgs.writeShellApplication {
    name = "mediNix-boot-watchdog";
    runtimeInputs = [ pkgs.systemd pkgs.curl ];
    text = ''
      set -euo pipefail
      NTFY="${ntfy}"
      REPORT=""

      # Check all known mediNix services
      for unit in ${unitList}; do
        if systemctl is-enabled --quiet "$unit.service" 2>/dev/null; then
          state="$(systemctl show "$unit.service" -p ActiveState --value || true)"
          
          # ONLY restart if explicitly failed! Not if merely inactive (e.g. missing mount)
          if [ "$state" = "failed" ]; then
            echo "Post-Boot: $unit failed, restarting..."
            if systemctl restart "$unit.service" 2>/dev/null; then
              REPORT="$REPORT $unit(restarted)"
            else
              echo "Error restarting $unit" >&2
              REPORT="$REPORT $unit(FAILED)"
            fi
          fi
        fi
      done

      if [ -n "$REPORT" ]; then
        curl -s -d "Boot-Watchdog: Services restarted:$REPORT" "$NTFY" || echo "NTFY Notification failed" >&2
      else
        curl -s -d "Boot-Watchdog: All services OK after 180s" "$NTFY" || echo "NTFY Notification failed" >&2
      fi
    '';
  };
in
lib.mkIf (cfg.enable && cfg.observability.postBootWatchdog) {
  systemd.timers.mediNix-boot-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec          = "180s";
      Unit               = "mediNix-boot-watchdog.service";
      RemainAfterElapse  = false;  # once, do not repeat
    };
  };

  systemd.services.mediNix-boot-watchdog = {
    serviceConfig = profiles.script // { Type = "oneshot"; };
    path = [ pkgs.systemd pkgs.curl ];
    script = "${lib.getExe script}";
  };
}
