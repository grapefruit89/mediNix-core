# ---
# id: "578-orphan-cleanup"
# title: "Orphan/Incomplete Cleanup (SABnzbd incomplete + orphaned fragments)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-5260 (sabnzbd), ADR-5043
#   skill: nixos-context7-gate
#   note: "Only paths under storage.mediaRoot. Never touch Library."
# context7:
#   - query: "systemd.timers OnCalendar daily example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "systemd.timers.<name>.timerConfig.OnCalendar = \"daily\";"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.maintenance.orphanCleanup;
  svc = config.medinix;
  incompleteDir = "${svc.storage.mediaRoot}/downloads/incomplete";
  completeDir   = "${svc.storage.mediaRoot}/downloads/complete";
in
lib.mkIf (svc.enable && cfg.enable) {
  systemd.timers.mediNix-orphan-cleanup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = cfg.schedule;
      Persistent = true;
    };
  };

  systemd.services.mediNix-orphan-cleanup = {
    description = "Remove orphaned SABnzbd incomplete + stale fragments (age > ${toString cfg.minAgeDays}d)";
    serviceConfig = lib.mkMerge [
      (import ../lib/hardening-profiles.nix { inherit lib; }).script
      {
        Type = "oneshot";
        User = "media";
        Group = "media";
        UMask = "002";
        ReadWritePaths = [ incompleteDir completeDir ];
        # Journal-Rate-Limit: prevent Log-IO storm in case of Permission/IO errors
        RateLimitBurst = 5;
        RateLimitIntervalSec = "30s";
      }
    ];
    script = ''
      set -euo pipefail
      INC="${incompleteDir}"
      COM="${completeDir}"

      # 1. SABnzbd incomplete: everything older than minAgeDays (orphaned)
      if [ -d "$INC" ]; then
        find "$INC" -mindepth 1 -mtime +${toString cfg.minAgeDays} -print0 | while IFS= read -r -d "" f; do
          rm -rf "$f"
        done
      fi

      # 2. Empty/obviously orphaned fragments under complete (never Library!)
      if [ -d "$COM" ]; then
        find "$COM" -mindepth 1 -type f -size 0 -mtime +${toString cfg.minAgeDays} -delete
      fi

      echo "Orphan cleanup done"
    '';
  };
}
