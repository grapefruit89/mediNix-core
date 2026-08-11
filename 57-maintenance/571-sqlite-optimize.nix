# ---
# id: "571-sqlite-optimize"
# title: "SQLite Weekly Optimize (PRAGMA optimize + wal_checkpoint TRUNCATE)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5700
#   skill: nixos-context7-gate
# context7:
#   - query: "systemd.timers OnCalendar example weekly interval"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "systemd.timers.<name>.timerConfig.OnCalendar = \"weekly\";"
# ---
{ config, lib, pkgs, ... }:

let
  svc = config.grapefruitMedia;
  arrStateDirs = [
    "/var/lib/prowlarr-5360" "/var/lib/sonarr-5320" "/var/lib/radarr-5330"
    "/var/lib/readarr-5340" "/var/lib/lidarr-5350" "/var/lib/sabnzbd-5410"
    "/var/lib/jellyfin-5510" "/var/lib/audiobookshelf-5520" "/var/lib/navidrome-5530"
    "/var/lib/jellyseerr-5610"
  ];
in
{
  systemd.timers.sqlite-optimize = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  systemd.services.sqlite-optimize = {
    description = "Weekly SQLite PRAGMA optimize + WAL checkpoint";
    serviceConfig = lib.mkMerge [
      # script-Profil: PrivateNetwork=true, MemoryDenyWriteExecute=true (bash)
      (import ../lib/hardening-profiles.nix { inherit lib; }).script
      {
        Type = "oneshot";
        User = "media";
        Group = "media";
        UMask = "002";
        ReadWritePaths = arrStateDirs;
      }
    ];
    script = ''
      set -euo pipefail
      for dir in ${lib.concatStringsSep " " arrStateDirs}; do
        if [ -d "$dir" ]; then
          find "$dir" -name '*.db' -type f | while read -r db; do
            ${pkgs.sqlite}/bin/sqlite3 "$db" \
              "PRAGMA optimize; PRAGMA wal_checkpoint(TRUNCATE);"
          done
        fi
      done
    '';
  };
}
