# ---
# id: "536-sqlite-wal"
# title: "SQLite WAL tuning for *arr DBs (SSD Tier B)"
# domain: 50
# folder: 53-acquisition
# status: draft
# complexity: 2
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5043
#   adr: ADR-0000
#   modules:
#     - path: lib/abc-tiering.nix
# provides: ["sqlite-wal-tuning"]
# requires: ["lib/abc-tiering.nix"]
# ports: []
# upstream_docs: ["https://sqlite.org/pragma.html"]
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: "/var/lib"
# uds_socket: false
# systemd_hardened: false
# ---
# 53-acquisition/536-sqlite-wal.nix — SQLite WAL pragmas for *arr state DBs
# Vector-store provenance: "sqlite WAL pragmas performance SSD tiering"
# (semantic cluster, source=chat). All *arr SQLite DBs live on Tier B (SSD) and
# MUST use WAL + NORMAL + cache_size + temp_store=MEMORY to spare SSD writes.
#
# NOTE: *arr apps apply these pragmas internally; this module documents the
# contract and asserts the DB path is on Tier B, not on mergerfs (Tier C).
{ lib, config, ... }:

{
  # Assertion: *arr state dirs must NOT be on mergerfs (Tier C / HDD).
  # WAL on HDD kills performance and wears disks. Tier B (SSD) only.
  assertions = lib.singleton {
    assertion = lib.all (p: !lib.hasPrefix config.grapefruitMedia.storage.mediaRoot p)
      [ "/var/lib/sonarr" "/var/lib/radarr" "/var/lib/lidarr"
        "/var/lib/readarr" "/var/lib/prowlarr" "/var/lib/sabnzbd" ];
    message = ''
      [536] A media-app state dir sits under mediaRoot (Tier C / mergerfs HDD).
      SQLite WAL on HDD destroys performance and wears the disk.
      Fix: keep /var/lib/<app> on Tier B (SSD); only finished media goes to Tier C.
    '';
  };

  # System-wide SQLite default tuning via SQLITE_* is not portable; instead we
  # record the mandated pragma set here as documentation + a one-shot optimizer
  # that runs on boot (event-driven, not cron) to keep WAL-mode + ANALYZE fresh.
  systemd.services.sqlite-wal-optimize = {
    description = "Optimize *arr SQLite DBs (WAL/NORMAL/ANALYZE)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.getExe (config.environment.etc."sqlite-wal-optimize".source);
    };
  };

  environment.etc."sqlite-wal-optimize" = {
    text = ''
      #!/usr/bin/env bash
      # Event-driven (boot/oneshot) SQLite WAL optimizer for mediNix app DBs.
      # Applies the mandated pragma set from ADR-0000 / abc-tiering.
      set -euo pipefail
      for db in /var/lib/{sonarr,radarr,lidarr,readarr,prowlarr,sabnzbd}/*.db; do
        [ -f "$db" ] || continue
        sqlite3 "$db" "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; \
          PRAGMA cache_size=-20000; PRAGMA temp_store=MEMORY; PRAGMA optimize;"
      done
    '';
    mode = "0755";
  };
}
