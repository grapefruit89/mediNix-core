# ---
# id: "576-backup"
# title: "Restic Backup mit DB-Safety (stoppt Dienste vor Backup)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-5700 (sqlite), ADR-5043 (assertion-quality)
#   repo-harvest: Nix-Grok (backup pattern)
#   context7: services.restic.backups (nixos_manual_unstable)
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  svc = config.grapefruitMedia;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };

  # Alle Dienste die SQLite/State haben — vor Backup stoppen (DB-Safety)
  mediaServices = [
    "sonarr-5320" "radarr-5330" "prowlarr-5360" "lidarr-5350" "readarr-5340"
    "sabnzbd-5410" "jellyfin-5510" "audiobookshelf-5520" "navidrome-5530"
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
  assertions = [
    {
      assertion = cfg.maintenance.backup.repository != "" && cfg.maintenance.backup.passwordFile != "";
      message = "[STORE-BACKUP] maintenance.backup.repository und passwordFile müssen gesetzt sein.";
    }
  ];

  services.restic.backups.mediNix = {
    paths = [ "/var/lib" ];
    repository = cfg.maintenance.backup.repository;
    passwordFile = cfg.maintenance.backup.passwordFile;
    timerConfig.OnCalendar = cfg.maintenance.backup.schedule;
    backupPrepareCommand = "${lib.getExe preCmd}";
    backupCleanupCommand = "${lib.getExe postCmd}";
  };
}
