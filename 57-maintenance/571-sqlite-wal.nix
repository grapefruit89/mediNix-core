# ---
# id: "571-sqlite-wal"
# title: "SQLite WAL Tuning + periodic optimize/ANALYZE for *arr/SABnzbd/Jellyfin (57-maintenance, Service 571)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-5700 (sqlite), ADR-5043
#   skill: nixos-context7-gate
#   repo-harvest: Prowlarr/Prowlarr #1614 (WAL cache_size=-20000)
# context7:
#   - query: "systemd.services oneshot ExecStartPost timer example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "oneshot service via Type=oneshot + script + timer"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.maintenance.sqliteOptimize;
  svc = config.grapefruitMedia;
  registry = (import ../lib/registry.nix { inherit lib; }).services;

  # Derive StateDirectory paths from Registry (ADR-0000: /var/lib/${name}-${port})
  # Only services that are listed in cfg.services + active.
  stateDirs = lib.mapAttrsToList
    (n: s: "/var/lib/${n}-${toString s.port}")
    (lib.filterAttrs (n: _: lib.elem n cfg.services) registry);

  optimizeScript = pkgs.writeShellApplication {
    name = "sqlite-optimize";
    runtimeInputs = [ pkgs.sqlite pkgs.findutils ];
    text = ''
      set -euo pipefail
      for dir in ${lib.concatStringsSep " " stateDirs}; do
        [ -d "$dir" ] || continue
        find "$dir" -name '*.db' -type f | while read -r db; do
          ${pkgs.sqlite}/bin/sqlite3 "$db" "
            PRAGMA journal_mode=WAL;
            PRAGMA synchronous=NORMAL;
            PRAGMA cache_size=-20000;
            PRAGMA temp_store=MEMORY;
            PRAGMA mmap_size=268435456;
            PRAGMA journal_size_limit=67108864;
            PRAGMA wal_autocheckpoint=1000;
            PRAGMA busy_timeout=5000;
            PRAGMA optimize;
            PRAGMA ANALYZE;
            PRAGMA incremental_vacuum;
          " || true  # no hard fail if DB is locked
        done
      done
      echo "SQLite optimize done"
    '';
  };
in
lib.mkIf (svc.enable && cfg.enable) {
  systemd.timers.mediNix-sqlite-optimize = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = cfg.schedule;
      Persistent = true;
    };
  };

  systemd.services.mediNix-sqlite-optimize = {
    description = "Periodic SQLite WAL + optimize/ANALYZE for media services";
    serviceConfig = lib.mkMerge [
      (import ../lib/hardening-profiles.nix { inherit lib; }).script
      {
        Type = "oneshot";
        User = "root";  # needs write to state dirs
        UMask = "002";
        ExecStart = lib.getExe optimizeScript;
        # Journal rate limit: prevent log IO storm in case of DB lock loop
        RateLimitBurst = 5;
        RateLimitIntervalSec = "30s";
      }
    ];
  };
}
