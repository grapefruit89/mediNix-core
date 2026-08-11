# ---
# id: "542-sqlite-wal"
# title: "SQLite WAL Tuning for *arr Stack (event-driven, no cron)"
# domain: 54
# folder: 54-transfer
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5700
#   skill: nixos-context7-gate
#   repo-harvest: Prowlarr/Prowlarr #1614 (SQLite WAL cache size=-20000; journal mode=Wal)
# context7:
#   - query: "systemd.services oneshot ExecStartPost example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "oneshot service via Type=oneshot + script"
# ---
{ config, lib, pkgs, ... }:

let
  svc = config.grapefruitMedia;
  # Alle Arr-State-Dirs (ADR-0000 §4: Port = Num × 10)
  arrStateDirs = [
    "/var/lib/prowlarr-5360"
    "/var/lib/sonarr-5320"
    "/var/lib/radarr-5330"
    "/var/lib/readarr-5340"
    "/var/lib/lidarr-5350"
    "/var/lib/sabnzbd-5410"
  ];
in
{
  # Event-driven WAL tuning: oneshot after each Arr service starts.
  # No legacy cron (ADR-5000 compliant).
  systemd.services.sqlite-wal-tune = {
    description = "Apply SQLite WAL pragmas to all *arr databases";
    after = [ "network-online.target" ] ++ lib.optional svc.services.prowlarr.enable "prowlarr.service"
      ++ lib.optional svc.services.sonarr.enable "sonarr.service"
      ++ lib.optional svc.services.radarr.enable "radarr.service"
      ++ lib.optional svc.services.readarr.enable "readarr.service"
      ++ lib.optional svc.services.lidarr.enable "lidarr.service";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";  # needs write to state dirs
      UMask = "002";
    };
    script = ''
      set -euo pipefail
      for dir in ${lib.concatStringsSep " " arrStateDirs}; do
        if [ -d "$dir" ]; then
          find "$dir" -name '*.db' -type f | while read -r db; do
            ${pkgs.sqlite}/bin/sqlite3 "$db" \
              "PRAGMA journal_mode=WAL; PRAGMA cache_size=-20000; PRAGMA synchronous=NORMAL; PRAGMA temp_store=MEMORY;"
          done
        fi
      done
    '';
  };
}
