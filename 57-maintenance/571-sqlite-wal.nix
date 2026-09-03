# ---
# id: "571-sqlite-wal"
# title: "SQLite WAL High-Performance Tuning + periodic Checkpoints"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-19
# links: 
# provides: []
# requires: ["lib/hardening-profiles", "lib/registry"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.maintenance.sqliteOptimize;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;

  # Only grab active services
  activeServices = lib.filterAttrs (n: _: svc.${n}.enable or false) registry;

  # Derive (systemd unit, StateDirectory) pairs from Registry
  serviceEntries = lib.mapAttrsToList
    (n: s: { unit = "${s.unitName}.service"; dir = "/var/lib/${n}-${toString s.port}"; })
    activeServices;

  # "unit dir" lines, fed to the scripts via a here-string so maintenance only
  # ever touches a service's own StateDirectory, and only while that service's
  # own unit is active — never a blind find over every configured StateDirectory.
  serviceEntriesLines = lib.concatMapStringsSep "\n" (e: "${e.unit} ${e.dir}") serviceEntries;

  # WAL Tuning PRAGMAs (High-Performance for >= 16GB RAM)
  tuningPragmas = ''
    PRAGMA journal_mode=WAL;
    PRAGMA synchronous=NORMAL;
    PRAGMA cache_size=-64000;
    PRAGMA temp_store=MEMORY;
    PRAGMA mmap_size=536870912;
    PRAGMA journal_size_limit=134217728;
    PRAGMA wal_autocheckpoint=2000;
    PRAGMA busy_timeout=10000;
  '';

  passiveScript = pkgs.writeShellApplication {
    name = "sqlite-passive";
    runtimeInputs = [ pkgs.sqlite pkgs.findutils pkgs.systemd ];
    text = ''
      set -euo pipefail
      SERVICE_ENTRIES='${serviceEntriesLines}'
      while read -r unit dir; do
        [ -d "$dir" ] || continue
        # Lifecycle coupling: only touch a service's own DBs while that
        # service's own unit is active — never maintain a stopped service.
        systemctl is-active --quiet "$unit" || continue
        find "$dir" -name '*.db' -type f | while read -r db; do
          ${pkgs.sqlite}/bin/sqlite3 "$db" "
            ${tuningPragmas}
            PRAGMA wal_checkpoint(PASSIVE);
          " || true
        done
      done <<< "$SERVICE_ENTRIES"
      echo "SQLite PASSIVE checkpoint done"
    '';
  };

  truncateScript = pkgs.writeShellApplication {
    name = "sqlite-truncate";
    runtimeInputs = [ pkgs.sqlite pkgs.findutils pkgs.systemd ];
    text = ''
      set -euo pipefail
      SERVICE_ENTRIES='${serviceEntriesLines}'
      while read -r unit dir; do
        [ -d "$dir" ] || continue
        # Lifecycle coupling: only touch a service's own DBs while that
        # service's own unit is active — never maintain a stopped service.
        systemctl is-active --quiet "$unit" || continue
        find "$dir" -name '*.db' -type f | while read -r db; do
          ${pkgs.sqlite}/bin/sqlite3 "$db" "
            ${tuningPragmas}
            PRAGMA wal_checkpoint(TRUNCATE);
            PRAGMA optimize;
            PRAGMA ANALYZE;
          " || true
        done
      done <<< "$SERVICE_ENTRIES"
      echo "SQLite TRUNCATE + optimize done"
    '';
  };
in
lib.mkIf (svc.enable && cfg.enable) {
  systemd.timers.mediNix-sqlite-passive = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/45";
      Persistent = true;
    };
  };

  systemd.services.mediNix-sqlite-passive = {
    description = "Periodic SQLite PASSIVE Checkpoint (45m)";
    serviceConfig = lib.mkMerge [
      (import ../lib/hardening-profiles.nix { inherit lib; }).script
      {
        Type = "oneshot";
        User = "root";  # needs write to state dirs
        UMask = "002";
        ExecStart = lib.getExe passiveScript;
        RateLimitBurst = 5;
        RateLimitIntervalSec = "30s";
      }
    ];
  };

  systemd.timers.mediNix-sqlite-truncate = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Use the configured schedule for the heavy truncate (default weekly, user might change to daily 04:00)
      OnCalendar = cfg.schedule;
      Persistent = true;
    };
  };

  systemd.services.mediNix-sqlite-truncate = {
    description = "Periodic SQLite TRUNCATE + optimize (Heavy)";
    serviceConfig = lib.mkMerge [
      (import ../lib/hardening-profiles.nix { inherit lib; }).script
      {
        Type = "oneshot";
        User = "root";
        UMask = "002";
        ExecStart = lib.getExe truncateScript;
        RateLimitBurst = 5;
        RateLimitIntervalSec = "30s";
      }
    ];
  };
}
