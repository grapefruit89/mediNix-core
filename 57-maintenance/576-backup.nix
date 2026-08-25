# ---
# id: "576-backup"
# title: "Restic Backup with DB-Safety (stops services before backup)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-13
# links: 
# provides: []
# requires: ["lib/registry"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5700 (sqlite), ADR-5043 (assertion-quality)
# repo-harvest: Nix-Grok (backup pattern)
# context7: services.restic.backups (nixos_manual_unstable)
# skill: medinix-implement-discipline (Phase A-E)
# ---

{ config, lib, pkgs, ... }:

let
  cfg = config.medinix;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };

  # Registry: StateDirectory paths of services (port suffix, NOT unit name!)
  registry = import ../lib/registry.nix { inherit lib; };
  mediaStateDirs = lib.mapAttrsToList
    (_: s: "/var/lib/${s.name}-${toString s.port}") registry.services;

  # Plain unit names (factory builds systemd.services."${name}", NO port suffix)
  mediaServices = [
    "sonarr.service" "radarr.service" "prowlarr.service" "lidarr.service" "readarr.service"
    "sabnzbd.service" "jellyfin.service" "audiobookshelf.service" "navidrome.service"
  ];

  preCmd = pkgs.writeShellApplication {
    name = "mediNix-backup-pre";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      set -euo pipefail
      echo "mediNix-backup: stopping services for DB-safety..."
      systemctl stop ${lib.concatStringsSep " " mediaServices} 2>/dev/null || true
      sleep 2  # Allow transactions to complete
    '';
  };

  postCmd = pkgs.writeShellApplication {
    name = "mediNix-backup-post";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      set -euo pipefail
      echo "mediNix-backup: restarting services..."
      systemctl start ${lib.concatStringsSep " " mediaServices} 2>/dev/null || true
    '';
  };
in
lib.mkIf (cfg.enable && cfg.maintenance.backup.enable) {
  assertions = [ {
    assertion = cfg.maintenance.backup.repository != "" && cfg.maintenance.backup.passwordFile != "";
    message = "[STORE-BACKUP] maintenance.backup.repository and passwordFile must be set.";
  } ];

  services.restic.backups.mediNix = {
    paths = mediaStateDirs ++ [ cfg.secrets.secretsDir ];
    repository = cfg.maintenance.backup.repository;
    passwordFile = cfg.maintenance.backup.passwordFile;
    timerConfig.OnCalendar = cfg.maintenance.backup.schedule;
    backupPrepareCommand = "${lib.getExe preCmd}";
    backupCleanupCommand = "${lib.getExe postCmd}";
    # Retention: 7 daily, 4 weekly, 6 monthly (Pareto: sufficient, no overkill)
    pruneOpts = [ "--keep-daily 7" "--keep-weekly 4" "--keep-monthly 6" ];
    extraBackupArgs = [
      # Exclude transcodes/caches/incomplete (ballast, not restore-relevant)
      "--exclude=/var/lib/jellyfin-5510/transcodes"
      "--exclude=/var/lib/sabnzbd-5410/incomplete"
      "--exclude=/var/lib/sabnzbd-5410/Downloads"
    ];
  };
}
