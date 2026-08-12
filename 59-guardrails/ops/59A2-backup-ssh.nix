# ---
# id: "59A2-backup-ssh"
# title: "Backup-SSH — beschränkter SSH-Key für Offsite-Backups (59-guardrails/ops)"
# domain: 59
# folder: 59-guardrails/ops
# status: active
# complexity: 2
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5940 (Backup Strategy)
#   skill: nixos-context7-gate
# ---
# Dedizierter SSH-Account nur für Backup-Transfers (Pull via rsync/ Borg).
# Kein Interactive-Login, nur Command-Restriction via authorizedKeys.
{ config, lib, ... }:
let
  cfg = config.grapefruitMedia;
in lib.mkIf cfg.security.backupSsh.enable {
  users.users.backup = {
    uid = 9002;
    isSystemUser = true;
    group = "media";
    home = "/var/lib/backup";
    openssh.authorizedKeys.keys = cfg.backupSsh.sshKeys;
    # Restriktive Shell: nur Borg/rsync erlauben
    shell = lib.mkDefault "/run/current-system/sw/bin/bash";
  };
  # ForceCommand via sshd_config Option (nur falls Borg genutzt)
  services.openssh.extraConfig = lib.mkIf cfg.backupSsh.restrictCommand ''
    Match User backup
      ForceCommand ${cfg.backupSsh.forceCommand}
  '';
}
