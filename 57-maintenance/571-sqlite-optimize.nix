# ---
# id: "571-sqlite-optimize"
# title: "SQLite WAL/VACUUM Optimizer (event-driven, no cron)"
# domain: 50
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-50-media
# provides: []
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: "systemd.services.<name>.serviceConfig"
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---
# 57-maintenance/571-sqlite-optimize.nix — SQLite WAL / VACUUM (Event-driven)
{ lib, pkgs, config, ... }:

{
  # Event-driven SQLite optimization (no cron!)
  # Runs on service stop (ExecStopPost) for all *arr databases
  systemd.services = lib.mapAttrs (_: svc: {
    serviceConfig = {
      ExecStopPost = "${pkgs.sqliteInteractive}/bin/sqlite3 /var/lib/${svc.name}/*.db 'PRAGMA wal_checkpoint(TRUNCATE); VACUUM;'";
    };
  }) config.grapefruitMedia.services or {};

  # System-wide optimization trigger
  systemd.services.mediNix-sqlite-optimize = {
    description = "SQLite Optimization";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.sqliteInteractive}/bin/sqlite3 /var/lib/*/*.db 'PRAGMA wal_checkpoint(TRUNCATE); VACUUM;'";
    };
  };
}
