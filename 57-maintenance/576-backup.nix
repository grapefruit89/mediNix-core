# ---
# id: "576-backup"
# title: "Restic Backup mit DB-Safety (stoppt Dienste vor Backup)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-5700 (sqlite), ADR-5043 (assertion-quality)
#   repo-harvest: Nix-Grok (backup pattern)
#   context7: services.restic.backups (nixos_manual_unstable)
#   skill: medinix-implement-discipline (Phase A-E)
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };

  # Registry: StateDirectory-Pfade der Dienste (Port-Suffix, NICHT Unit-Name!)
  registry = import ../lib/registry.nix { inherit lib; };
  mediaStateDirs = lib.mapAttrsToList
    (_: s: "/var/lib/${s.name}-${toString s.port}") registry.services;

  # Plain Unit-Namen (Factory baut systemd.services."${name}", KEIN Port-Suffix)
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
      sleep 2  # Transaktionen abschließen lassen
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
    message = "[STORE-BACKUP] maintenance.backup.repository und passwordFile müssen gesetzt sein.";
  } ];

  services.restic.backups.mediNix = {
    paths = mediaStateDirs ++ [ cfg.secrets.secretsDir ];
    repository = cfg.maintenance.backup.repository;
    passwordFile = cfg.maintenance.backup.passwordFile;
    timerConfig.OnCalendar = cfg.maintenance.backup.schedule;
    backupPrepareCommand = "${lib.getExe preCmd}";
    backupCleanupCommand = "${lib.getExe postCmd}";
    # Retention: 7 täglich, 4 wöchentlich, 6 monatlich (Pareto: ausreichend, kein Overkill)
    pruneOpts = [ "--keep-daily 7" "--keep-weekly 4" "--keep-monthly 6" ];
    extraBackupArgs = [
      # Transcodes/Caches/Incomplete ausschließen (Ballast, nicht restore-relevant)
      "--exclude=/var/lib/jellyfin-5510/transcodes"
      "--exclude=/var/lib/sabnzbd-5410/incomplete"
      "--exclude=/var/lib/sabnzbd-5410/Downloads"
    ];
  };
}
