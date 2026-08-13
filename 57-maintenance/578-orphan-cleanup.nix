# ---
# id: "578-orphan-cleanup"
# title: "Orphan/Incomplete Cleanup (SABnzbd incomplete + verwaiste Fragmente)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-5410 (sabnzbd), ADR-5043
#   skill: nixos-context7-gate
#   note: "Nur Pfade unter storage.mediaRoot. Niemals Library anfassen."
# context7:
#   - query: "systemd.timers OnCalendar daily example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "systemd.timers.<name>.timerConfig.OnCalendar = \"daily\";"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.maintenance.orphanCleanup;
  svc = config.grapefruitMedia;
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
      }
    ];
    script = ''
      set -euo pipefail
      INC="${incompleteDir}"
      COM="${completeDir}"

      # 1. SABnzbd incomplete: alles was älter als minAgeDays ist (verwaist)
      if [ -d "$INC" ]; then
        find "$INC" -mindepth 1 -mtime +${toString cfg.minAgeDays} -print0 | while IFS= read -r -d '' f; do
          rm -rf "$f"
        done
      fi

      # 2. Leere/offensichtlich verwaiste Fragmente unter complete (nie Library!)
      if [ -d "$COM" ]; then
        find "$COM" -mindepth 1 -type f -size 0 -mtime +${toString cfg.minAgeDays} -delete
      fi

      echo "Orphan cleanup done"
    '';
  };
}
