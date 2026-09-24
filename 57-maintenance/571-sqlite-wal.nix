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
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.maintenance.sqliteOptimize;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;

  # Only grab active services that have a state directory and systemd unit
  activeServices = lib.filterAttrs (
    n: s: s.stateDir != null && s.unitName != null && (svc.${n}.enable or false)
  ) registry;

  # Derive (systemd unit, StateDirectory, uid:gid) triples from Registry
  serviceEntries = lib.mapAttrsToList (n: s: {
    unit = "${s.unitName}.service";
    dir = s.stateDir;
    owner = "${toString s.uid}:${toString s.gid}";
  }) activeServices;

  serviceEntriesLines = lib.concatMapStringsSep "\n" (
    e: "${e.unit} ${e.dir} ${e.owner}"
  ) serviceEntries;

  passiveScript = pkgs.writeShellApplication {
    name = "sqlite-passive";
    runtimeInputs = [
      pkgs.sqlite
      pkgs.findutils
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail
      SERVICE_ENTRIES='${serviceEntriesLines}'
      while read -r unit dir owner; do
        [ -d "$dir" ] || continue
        [ -n "$owner" ] || continue
        # Non-blocking passive checkpoint while service is running
        systemctl is-active --quiet "$unit" || continue
        while IFS= read -r -d $'\0' db; do
          [ -f "$db" ] || continue
          ${pkgs.sqlite}/bin/sqlite3 "$db" "
            PRAGMA busy_timeout=5000;
            PRAGMA wal_checkpoint(PASSIVE);
          " || true
        done < <(find "$dir" -name '*.db' -type f -print0 2>/dev/null)
        # Restore ownership so root does not leave locked -wal or -shm files
        chown -R "$owner" "$dir" 2>/dev/null || true
      done <<< "$SERVICE_ENTRIES"
      echo "SQLite PASSIVE checkpoint done"
    '';
  };

  truncateScript = pkgs.writeShellApplication {
    name = "sqlite-truncate";
    runtimeInputs = [
      pkgs.sqlite
      pkgs.findutils
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail
      SERVICE_ENTRIES='${serviceEntriesLines}'
      while read -r unit dir owner; do
        [ -d "$dir" ] || continue
        [ -n "$owner" ] || continue

        # Collect database files
        mapfile -d $'\0' dbs < <(find "$dir" -name '*.db' -type f -print0 2>/dev/null)
        [ "''${#dbs[@]}" -gt 0 ] || continue

        # Lifecycle coupling: safely stop the writer before heavy checkpoint/analyze
        WAS_ACTIVE=0
        if systemctl is-active --quiet "$unit"; then
          WAS_ACTIVE=1
          echo "SQLite maintenance: stopping $unit for safe checkpoint..."
          systemctl stop "$unit" || true
          sleep 1
        fi

        for db in "''${dbs[@]}"; do
          [ -f "$db" ] || continue
          echo "SQLite optimize: maintaining $db"
          ${pkgs.sqlite}/bin/sqlite3 "$db" "
            PRAGMA busy_timeout=10000;
            PRAGMA journal_mode=WAL;
            PRAGMA synchronous=NORMAL;
            PRAGMA wal_checkpoint(TRUNCATE);
            PRAGMA optimize;
            PRAGMA ANALYZE;
          " || echo "Warning: sqlite optimization failed on $db" >&2
        done

        # Restore ownership so service can write to its WAL/SHM
        chown -R "$owner" "$dir" 2>/dev/null || true

        # Restart service if it was running before
        if [ "$WAS_ACTIVE" -eq 1 ]; then
          echo "SQLite maintenance: restarting $unit..."
          systemctl start "$unit" || true
        fi
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
        User = "root"; # needs write to state dirs
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
