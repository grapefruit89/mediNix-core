# ---
# id: "576-backup"
# title: "Restic Backup with DB-Safety (stops services before backup)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 4
# last_reviewed: 2026-08-28
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
# adr: ADR-5721 (backup data classification), ADR-5700 (sqlite), ADR-5043 (assertion-quality)
# repo-harvest: Nix-Grok (backup pattern)
# context7: services.restic.backups (nixos_manual_unstable)
# skill: medinix-implement-discipline (Phase A-E)
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix;
  bkp = cfg.maintenance.backup;
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

  # Fail-Closed credential wiring (ADR-5721): if passwordCredentialPath is set,
  # the primary backup password comes from systemd-creds instead of a plain
  # passwordFile. Mirrors 52-security/525-vpn-interface.nix (WireGuard key).
  primaryUsesCreds = bkp.passwordCredentialPath != null;
  primaryPasswordFile =
    if primaryUsesCreds
    then "/run/credentials/restic-backups-mediNix.service/restic-password"
    else bkp.passwordFile;

  offsiteUsesCreds = bkp.offsite.passwordCredentialPath != null;
  offsitePasswordFile =
    if offsiteUsesCreds
    then "/run/credentials/mediNix-backup-offsite-copy.service/restic-password-offsite"
    else bkp.offsite.passwordFile;

  ntfyPort = registry.services.ntfy.port;
  ntfyUrl  = "http://127.0.0.1:${toString ntfyPort}/${cfg.observability.ntfy.topic or "mediNix-backup"}";
  ntfyEnabled = cfg.observability.ntfy.enable or false;

  offsiteCopyCmd = pkgs.writeShellApplication {
    name = "mediNix-backup-offsite-copy";
    runtimeInputs = [ pkgs.restic pkgs.rclone pkgs.curl ];
    text = ''
      set -euo pipefail
      echo "mediNix-backup: replicating latest local snapshot to offsite repository..."
      if ! restic -r "${bkp.offsite.repository}" --password-file "${offsitePasswordFile}" \
          copy --from-repo "${bkp.repository}" --from-password-file "${primaryPasswordFile}"; then
        echo "mediNix-backup-offsite: copy FAILED" >&2
        ${lib.optionalString ntfyEnabled ''
          curl -s -H "Title: mediNix Offsite-Backup FAILED" -H "Tags: warning,cloud" -H "Priority: 4" \
            -d "restic copy --from-repo -> offsite repository failed. Local backup is fine, offsite copy is NOT up to date." \
            "${ntfyUrl}" || true
        ''}
        exit 1
      fi
      echo "mediNix-backup: offsite replication OK."
    '';
  };

  checkCmd = pkgs.writeShellApplication {
    name = "mediNix-backup-check";
    runtimeInputs = [ pkgs.restic pkgs.curl ];
    text = ''
      set -euo pipefail
      echo "mediNix-backup: verifying repository integrity (restic check)..."
      if ! restic -r "${bkp.repository}" --password-file "${primaryPasswordFile}" check; then
        echo "mediNix-backup-check: restic check FAILED" >&2
        ${lib.optionalString ntfyEnabled ''
          curl -s -H "Title: mediNix Backup Integrity Check FAILED" -H "Tags: rotating_light,floppy_disk" -H "Priority: 5" \
            -d "restic check failed on the primary backup repository. Investigate before you need to restore from it." \
            "${ntfyUrl}" || true
        ''}
        exit 1
      fi
      echo "mediNix-backup: integrity check OK."
    '';
  };
in
lib.mkIf (cfg.enable && bkp.enable) {
  assertions = [
    {
      assertion = bkp.repository != "";
      message = ''
        [mediNix] maintenance.backup.repository is empty.

        [AI/Admin Context]
        Reason: mediNix does not choose a backup destination for you (ADR-5710: host
        mounts/supplies infra-specifics, flake supplies structure). Without a
        repository, restic has nowhere to write and the timer fails every run.
        Fix: Set medinix.maintenance.backup.repository (local path, sftp:, rclone:<remote>:, ...).
        Ref: ADR-5721 (Backup Data Classification)
      '';
    }
    {
      assertion = bkp.passwordCredentialPath != null || bkp.passwordFile != "";
      message = ''
        [mediNix] Neither maintenance.backup.passwordCredentialPath nor
        maintenance.backup.passwordFile is set.

        [AI/Admin Context]
        Reason: Fail-Closed by design (BANNED_TECHNOLOGIES.md) -- a restic repository
        without a password is either unencrypted or unusable. We refuse to build
        rather than start a backup service with an empty password.
        Fix (recommended): systemd-creds encrypt the password, then set
        passwordCredentialPath, e.g.
          sudo ./57-maintenance/medinix-seal-secret.sh restic-password '<your-password>'
          medinix.maintenance.backup.passwordCredentialPath =
            "/var/lib/medinix/secrets/restic-password.encrypted";
        Fix (legacy/external): medinix.maintenance.backup.passwordFile = "/path/to/password/file";
        Ref: ADR-5721 (Backup Data Classification)
      '';
    }
    {
      assertion = !bkp.offsite.enable || bkp.offsite.repository != "";
      message = ''
        [mediNix] maintenance.backup.offsite.enable is true but offsite.repository is empty.

        [AI/Admin Context]
        Reason: offsite replication needs a second, physically/logically separate
        repository (3-2-1 rule) -- otherwise it silently does nothing useful.
        Fix: Set medinix.maintenance.backup.offsite.repository (e.g.
        rclone:koofr:mediNix-backup for WebDAV cloud storage, or a path on a second
        external disk).
        Ref: ADR-5721 (Backup Data Classification)
      '';
    }
    {
      assertion = !bkp.offsite.enable || bkp.offsite.passwordCredentialPath != null || bkp.offsite.passwordFile != "";
      message = ''
        [mediNix] maintenance.backup.offsite.enable is true but neither
        offsite.passwordCredentialPath nor offsite.passwordFile is set.

        [AI/Admin Context]
        Reason: same Fail-Closed rule as the primary repository, see above.
        Ref: ADR-5721 (Backup Data Classification)
      '';
    }
  ];

  services.restic.backups.mediNix = {
    paths = mediaStateDirs ++ [ cfg.secrets.secretsDir ];
    repository = bkp.repository;
    passwordFile = primaryPasswordFile;
    timerConfig.OnCalendar = bkp.schedule;
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

  # Fail-Closed credential wiring (ADR-5721): mirrors the WireGuard private-key
  # pattern in 52-security/525-vpn-interface.nix. Only active when
  # passwordCredentialPath is set -- default behaviour (plain passwordFile) is
  # unchanged for existing hosts.
  systemd.services."restic-backups-mediNix".serviceConfig = lib.mkIf primaryUsesCreds {
    LoadCredentialEncrypted = "restic-password:${toString bkp.passwordCredentialPath}";
  };

  # Offsite replication (ADR-5721 / 3-2-1): runs ONLY after the primary backup
  # succeeds, and copies already-consistent snapshots -- no second service-stop
  # cycle needed.
  systemd.services."restic-backups-mediNix".unitConfig.OnSuccess =
    lib.mkIf bkp.offsite.enable [ "mediNix-backup-offsite-copy.service" ];

  systemd.services."mediNix-backup-offsite-copy" = lib.mkIf bkp.offsite.enable {
    description = "mediNix offsite backup replication (restic copy)";
    serviceConfig = lib.mkMerge [
      profiles.client
      ({
        Type = "oneshot";
        ExecStart = lib.getExe offsiteCopyCmd;
      }
      // lib.optionalAttrs offsiteUsesCreds {
        LoadCredentialEncrypted = "restic-password-offsite:${toString bkp.offsite.passwordCredentialPath}";
      }
      // lib.optionalAttrs (bkp.offsite.rcloneConfigFile != null) {
        LoadCredential = "rclone.conf:${toString bkp.offsite.rcloneConfigFile}";
      })
    ];
    environment = lib.mkIf (bkp.offsite.rcloneConfigFile != null) {
      RCLONE_CONFIG = "%d/rclone.conf";
    };
  };

  # Weekly integrity verification (restic check) on the primary repository.
  # Assumes the primary repository is local/on-LAN (script profile = loopback
  # only, no internet). If you point maintenance.backup.repository itself at a
  # remote/cloud target, switch this to profiles.client instead.
  systemd.services."mediNix-backup-check" = {
    description = "mediNix restic repository integrity check";
    serviceConfig = lib.mkMerge [
      profiles.script
      ({
        Type = "oneshot";
        ExecStart = lib.getExe checkCmd;
      }
      // lib.optionalAttrs primaryUsesCreds {
        LoadCredentialEncrypted = "restic-password:${toString bkp.passwordCredentialPath}";
      })
    ];
  };
  systemd.timers."mediNix-backup-check" = {
    description = "Weekly restic integrity verification";
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "weekly";
    timerConfig.Persistent = true;
  };
}
