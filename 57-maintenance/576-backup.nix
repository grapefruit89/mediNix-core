# ---
# id: "576-backup"
# title: "Backup of class-A2 state (Restic & optional SSH-pull, DB-safe stop)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-11-26
# provides: ["backup"]
# requires: ["50-core/hardening-profiles", "50-core/registry"]
# links:
#   adr: ADR-576
# ---
# Kanonisches Backup-Modul (ADR-576):
#   1. Restic-Backup der A2-State-Verzeichnisse mit DB-Safe Stop/Start
#   2. Optionales Offsite-Copy (z. B. S3, SFTP via rclone) & wöchentlicher Check
#   3. Optionaler SSH-Pull-User (backup) für externe Backups via rsync/Polkit
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix;
  bkp = cfg.maintenance.backup;
  sshCfg = cfg.security.backupSsh;
  profiles = import ../50-core/hardening-profiles.nix { inherit lib; };
  registry = import ../50-core/registry.nix { inherit lib; };

  optEnable =
    name:
    if name == "pocket-id" then
      cfg.pocketId.enable or false
    else if name == "caddy" then
      cfg.ingress.enable or false
    else
      cfg.${name}.enable or false;

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
      ${lib.optionalString (mediaServices != [ ]) ''
        systemctl stop ${lib.concatStringsSep " " mediaServices} || true
      ''}
    '';
  };

  postCmd = pkgs.writeShellApplication {
    name = "mediNix-backup-post";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      set -euo pipefail
      echo "mediNix-backup: restarting writers..."
      ${lib.optionalString (mediaServices != [ ]) ''
        systemctl start ${lib.concatStringsSep " " mediaServices} || true
      ''}
    '';
  };

  primaryPasswordFile = "/run/credentials/restic-backups-mediNix.service/restic-password";
  offsitePasswordFile = "/run/credentials/mediNix-backup-offsite-copy.service/restic-password-offsite";

  ntfyPort = registry.services.ntfy.port;
  ntfyUrl = "http://127.0.0.1:${toString ntfyPort}/${
    cfg.observability.ntfy.topic or "mediNix-backup"
  }";
  ntfyEnabled = cfg.observability.ntfy.enable or false;

  offsiteCopyCmd = pkgs.writeShellApplication {
    name = "mediNix-backup-offsite-copy";
    runtimeInputs = [
      pkgs.restic
      pkgs.rclone
      pkgs.curl
    ];
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
    runtimeInputs = [
      pkgs.restic
      pkgs.curl
    ];
    text = ''
      set -euo pipefail
      echo "mediNix-backup: checking repository integrity..."
      if ! restic -r "${bkp.repository}" --password-file "${primaryPasswordFile}" check; then
        ${lib.optionalString ntfyEnabled ''
          curl -s -H "Title: mediNix Backup Integrity FAILED" -H "Tags: skull,database" -H "Priority: 5" \
            -d "Local restic repository check failed. Investigate immediately." \
            "${ntfyUrl}" || true
        ''}
        exit 1
      fi
    '';
  };

  # SSH-Pull Units & Polkit
  units = lib.mapAttrsToList (_: s: "${s.unitName}.service") stateful;
  unitList = lib.concatMapStringsSep ", " (u: "\"${u}\"") units;
in
{
  config = lib.mkMerge [
    # ── Restic Backup Engine ─────────────────────────────────────────────────
    (lib.mkIf bkp.enable {
      assertions = [
        {
          assertion = bkp.repository != "";
          message = "mediNix: maintenance.backup.repository must be set when backup is enabled.";
        }
        {
          assertion = bkp.passwordCredentialPath != null || bkp.passwordFile != "";
          message = "mediNix: maintenance.backup requires either passwordCredentialPath (preferred, systemd-creds) or passwordFile.";
        }
        {
          assertion = !(bkp.offsite.enable && bkp.offsite.repository == "");
          message = "mediNix: maintenance.backup.offsite.repository must be set when offsite backup is enabled.";
        }
        {
          assertion = !(bkp.offsite.enable && bkp.offsite.passwordCredentialPath == null);
          message = "mediNix: maintenance.backup.offsite.passwordCredentialPath must be set when offsite backup is enabled.";
        }
      ];

      services.restic.backups.mediNix = {
        inherit (bkp) repository;
        paths = mediaStateDirs ++ [ cfg.secrets.secretsDir ];
        passwordFile = primaryPasswordFile;
        timerConfig.OnCalendar = bkp.schedule;
        backupPrepareCommand = lib.getExe preCmd;
        backupCleanupCommand = lib.getExe postCmd;
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];
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

      systemd.services."restic-backups-mediNix".unitConfig.OnSuccess = lib.mkIf bkp.offsite.enable [
        "mediNix-backup-offsite-copy.service"
      ];

      systemd.services."mediNix-backup-offsite-copy" = lib.mkIf bkp.offsite.enable {
        description = "mediNix offsite restic copy";
        serviceConfig = lib.mkMerge [
          profiles.client
          {
            Type = "oneshot";
            ExecStart = lib.getExe offsiteCopyCmd;
            LoadCredentialEncrypted = lib.mkMerge [
              [ "restic-password-offsite:${toString bkp.offsite.passwordCredentialPath}" ]
              (lib.optional (
                bkp.offsite.rcloneConfigFile != null
              ) "rclone.conf:${toString bkp.offsite.rcloneConfigFile}")
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
    })

    # ── Optionaler SSH-Pull Backup User (ehemals 579-backup-ssh) ─────────────
    (lib.mkIf sshCfg.enable {
      users.users.backup = {
        isNormalUser = true;
        extraGroups = [ "media" ];
        openssh.authorizedKeys.keys = sshCfg.sshKeys;
      };

      services.openssh.extraConfig = ''
        Match User backup
          AllowTcpForwarding no
          X11Forwarding no
          PermitTTY no
          ForceCommand ${pkgs.rsync}/bin/rsync --server --sender -vlogDtprze.iLsfxCIvu . /var/lib/
      '';

      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          var allowedUnits = [ ${unitList} ];
          if (action.id == "org.freedesktop.systemd1.manage-units" && subject.user == "backup") {
            var unit = action.lookup("unit");
            if (allowedUnits.indexOf(unit) !== -1) {
              return polkit.Result.YES;
            }
          }
        });
      '';
    })
  ];
}
