# ---
# id: "576-backup"
# title: "Restic backup of class-A2 state (registry paths, DB-safe stop)"
# domain: 57
# folder: 57-maintenance
# status: active
# last_reviewed: 2026-09-02
# provides: ["backup"]
# requires: ["lib/hardening-profiles", "lib/registry"]
# adr: ADR-576
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix;
  bkp = cfg.maintenance.backup;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  registry = import ../lib/registry.nix { inherit lib; };

  optEnable = name:
    if name == "pocket-id" then cfg.pocketId.enable or false
    else if name == "caddy" then cfg.ingress.enable or false
    else cfg.${name}.enable or false;

  stateful = lib.filterAttrs (_: s: s.stateDir != null) registry.services;
  enabledStateful = lib.filterAttrs (n: _: optEnable n) stateful;

  mediaStateDirs = lib.mapAttrsToList (_: s: s.stateDir) enabledStateful;

  stoppable = lib.filterAttrs (n: _: n != "caddy") enabledStateful;
  mediaServices = lib.mapAttrsToList (_: s: "${s.unitName}.service") stoppable;

  preCmd = pkgs.writeShellApplication {
    name = "mediNix-backup-pre";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      set -euo pipefail
      echo "mediNix-backup: stopping writers for DB-safety..."
      ${lib.optionalString (mediaServices != []) ''
        systemctl stop ${lib.concatStringsSep " " mediaServices} || true
        sleep 2
      ''}
    '';
  };

  postCmd = pkgs.writeShellApplication {
    name = "mediNix-backup-post";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      set -euo pipefail
      echo "mediNix-backup: restarting writers..."
      ${lib.optionalString (mediaServices != []) ''
        systemctl start ${lib.concatStringsSep " " mediaServices} || true
      ''}
    '';
  };

  primaryPasswordFile =
    "/run/credentials/restic-backups-mediNix.service/restic-password";

  offsitePasswordFile =
    "/run/credentials/mediNix-backup-offsite-copy.service/restic-password-offsite";

  ntfyPort = registry.services.ntfy.port;
  ntfyUrl = "http://127.0.0.1:${toString ntfyPort}/${cfg.observability.ntfy.topic or "mediNix-backup"}";
  ntfyEnabled = cfg.observability.ntfy.enable or false;

  offsiteCopyCmd = pkgs.writeShellApplication {
    name = "mediNix-backup-offsite-copy";
    runtimeInputs = [ pkgs.restic pkgs.rclone pkgs.curl ];
    text = ''
      set -euo pipefail
      echo "mediNix-backup: replicating latest snapshot offsite..."
      if ! restic -r "${bkp.offsite.repository}" --password-file "${offsitePasswordFile}" \
          copy --from-repo "${bkp.repository}" --from-password-file "${primaryPasswordFile}"; then
        ${lib.optionalString ntfyEnabled ''
          curl -s -H "Title: mediNix Offsite-Backup FAILED" -H "Tags: warning,cloud" -H "Priority: 4" \
            -d "restic copy to offsite failed. Local snapshot may still be fine." \
            "${ntfyUrl}" || true
        ''}
        exit 1
      fi
    '';
  };

  checkCmd = pkgs.writeShellApplication {
    name = "mediNix-backup-check";
    runtimeInputs = [ pkgs.restic pkgs.curl ];
    text = ''
      set -euo pipefail
      if ! restic -r "${bkp.repository}" --password-file "${primaryPasswordFile}" check; then
        ${lib.optionalString ntfyEnabled ''
          curl -s -H "Title: mediNix Backup Integrity Check FAILED" -H "Tags: rotating_light,floppy_disk" -H "Priority: 5" \
            -d "restic check failed on the primary repository." \
            "${ntfyUrl}" || true
        ''}
        exit 1
      fi
    '';
  };
in
lib.mkIf (cfg.enable && bkp.enable) {
  assertions = [
    {
      assertion = bkp.repository != "";
      message = ''
        [mediNix] maintenance.backup.repository is empty.
        Host supplies the destination (local path, sftp:, rclone:...). Ref: ADR-576.
      '';
    }
    {
      assertion = bkp.passwordCredentialPath != null;
      message = ''
        [mediNix] set passwordCredentialPath (sealed systemd-creds).
        passwordFile is not accepted. Ref: ADR-576.
      '';
    }
    {
      assertion = !bkp.offsite.enable || bkp.offsite.repository != "";
      message = "[mediNix] offsite.enable requires offsite.repository (3-2-1)."
    }
    {
      assertion = !bkp.offsite.enable || bkp.offsite.passwordCredentialPath != null;
      message = "[mediNix] offsite.enable requires offsite.passwordCredentialPath."
    }
  ];

  services.restic.backups.mediNix = {
    paths = mediaStateDirs ++ [ cfg.secrets.secretsDir ];
    repository = bkp.repository;
    passwordFile = primaryPasswordFile;
    timerConfig.OnCalendar = bkp.schedule;
    backupPrepareCommand = lib.getExe preCmd;
    backupCleanupCommand = lib.getExe postCmd;
    pruneOpts = [ "--keep-daily 7" "--keep-weekly 4" "--keep-monthly 6" ];
    extraBackupArgs = [
      "--exclude=transcodes"
      "--exclude=cache"
      "--exclude=Cache"
      "--exclude=incomplete"
      "--exclude=Downloads"
      "--exclude=logs"
    ];
  };

  systemd.services."restic-backups-mediNix".serviceConfig = {
    LoadCredentialEncrypted = "restic-password:${toString bkp.passwordCredentialPath}";
  };

  systemd.services."restic-backups-mediNix".unitConfig.OnSuccess =
    lib.mkIf bkp.offsite.enable [ "mediNix-backup-offsite-copy.service" ];

  systemd.services."mediNix-backup-offsite-copy" = lib.mkIf bkp.offsite.enable {
    description = "mediNix offsite restic copy";
    serviceConfig = lib.mkMerge [
      profiles.client
      {
        Type = "oneshot";
        ExecStart = lib.getExe offsiteCopyCmd;
        LoadCredentialEncrypted = lib.mkMerge [
          [ "restic-password-offsite:${toString bkp.offsite.passwordCredentialPath}" ]
          (lib.optional (bkp.offsite.rcloneConfigFile != null)
            "rclone.conf:${toString bkp.offsite.rcloneConfigFile}")
        ];
      }
    ];
    environment = lib.mkIf (bkp.offsite.rcloneConfigFile != null) {
      RCLONE_CONFIG = "%d/rclone.conf";
    };
  };

  systemd.services."mediNix-backup-check" = {
    description = "mediNix restic check";
    serviceConfig = lib.mkMerge [
      profiles.script
      {
        Type = "oneshot";
        ExecStart = lib.getExe checkCmd;
        LoadCredentialEncrypted = "restic-password:${toString bkp.passwordCredentialPath}";
      }
    ];
  };
  systemd.timers."mediNix-backup-check" = {
    description = "Weekly restic check";
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "weekly";
    timerConfig.Persistent = true;
  };
}
