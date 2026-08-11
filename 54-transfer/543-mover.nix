# ---
# id: "543-mover"
# title: "Tier-B Cleanup — deletes already-imported downloads older than retentionDays"
# domain: 54
# folder: 54-transfer
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5410
#   skill: nixos-context7-gate
#   note: "Sonarr/Radarr do the import (Tier B SSD -> Tier C HDD) themselves.
#          Hardlinks cross-FS impossible (SSD vs HDD) -> copy, so download stays
#          on Tier B until this cleanup removes it. No 'mv downloads -> library'."
# context7:
#   - query: "systemd.timers OnCalendar example interval"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "systemd.timers.<name>.timerConfig.OnCalendar = \"*:0/15\";"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.maintenance.mover;
  svc = config.grapefruitMedia;
  completeDir = "${svc.storage.mediaRoot}/downloads/complete";
in lib.mkIf cfg.enable {
  # Systemd Timer (ADR-5000: event/timer-driven, no legacy cron)
  systemd.timers.tier-b-cleanup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/15";  # alle 15 Minuten prüfen
      Persistent = true;
    };
  };

  systemd.services.tier-b-cleanup = {
    description = "Tier-B Cleanup: remove already-imported downloads older than ${toString cfg.retentionDays}d";
    serviceConfig = lib.mkMerge [
      # script-Profil: MemoryDenyWriteExecute=true (bash), PrivateNetwork=true
      (import ../lib/hardening-profiles.nix { inherit lib; }).script
      {
        Type = "oneshot";
        User = "media";
        Group = "media";
        UMask = "002";
        ReadWritePaths = [ completeDir ];
      }
    ];
    script = ''
      set -euo pipefail
      COMPLETE="${completeDir}"
      [ -d "$COMPLETE" ] || exit 0

      # Entferne Dateien/Ordner die älter als retentionDays sind.
      # Sonarr/Radarr importieren selbst (Tier B -> Tier C). Was älter als X Tage
      # ist, gilt als importiert + sicher auf Tier C -> Tier B freimachen.
      # Kein Hardlink möglich (SSD vs HDD) -> copy, daher hier Aufräumen.
      find "$COMPLETE" -mindepth 1 -mtime +${toString cfg.retentionDays} -print0 \
        | while IFS= read -r -d '' item; do
            rm -rf "$item"
          done
    '';
  };
}
