# ---
# id: "543-mover"
# title: "Smart Mover — shifts completed downloads to library (systemd timer, every 15m)"
# domain: 54
# folder: 54-transfer
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5410
#   skill: nixos-context7-gate
# context7:
#   - query: "systemd.timers OnCalendar example interval"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "systemd.timers.<name>.timerConfig.OnCalendar = \"*:0/15\";"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.storage;
  mediaRoot = cfg.mediaRoot;
  completeDir = "${mediaRoot}/downloads/complete";
  libraryDir  = "${mediaRoot}/library";
in
{
  # Systemd Timer (ADR-5000: event/timer-driven, no legacy cron)
  systemd.timers.media-mover = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/15";  # alle 15 Minuten
      Persistent = true;
    };
  };

  systemd.services.media-mover = {
    description = "Move completed downloads to media library";
    serviceConfig = {
      Type = "oneshot";
      User = "media";
      Group = "media";
      UMask = "002";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [ mediaRoot ];
    };
    script = ''
      set -euo pipefail
      COMPLETE="${completeDir}"
      LIBRARY="${libraryDir}"

      if [ ! -d "$COMPLETE" ]; then
        exit 0
      fi

      mkdir -p "$LIBRARY"

      # Verschiebe Ordner/Dateien von complete nach library, vermeide partial moves (.partial, etc.)
      find "$COMPLETE" -mindepth 1 -maxdepth 1 ! -name '*.partial' ! -name '.*' | while read -r item; do
        if [ -e "$item" ]; then
          mv -u "$item" "$LIBRARY/"
        fi
      done
    '';
  };
}
