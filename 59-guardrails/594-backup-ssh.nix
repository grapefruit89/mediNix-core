# ---
# id: "594-backup-ssh"
# title: "Backup-SSH — read-only SSH access for State-Dir backups (rsync/pull)"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5000, ADR-21-security-hardening
# provides: []
# requires: ["593-no-password-auth"]
# ports: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.security.backupSsh;
  # Alle State-Dirs die für Backup freigegeben sind (read-only)
  stateDirs = [
    "/var/lib/jellyfin-5510" "/var/lib/audiobookshelf-5520" "/var/lib/navidrome-5530"
    "/var/lib/sonarr-5320" "/var/lib/radarr-5330" "/var/lib/readarr-5340"
    "/var/lib/lidarr-5350" "/var/lib/prowlarr-5360" "/var/lib/sabnzbd-5410"
    "/var/lib/jellyseerr-5610" "/var/lib/ntfy-sh-5810" "/var/lib/recyclarr-5600"
  ];
in lib.mkIf cfg.enable {
  users.users.backup = {
    isSystemUser = true;
    group = "media";
    home = "/var/empty";
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = cfg.sshKeys;
  };
  users.groups.media.gid = 5000;

  # Read-only SSH: nur rsync/ cat erlaubt, kein shell-write
  services.openssh.extraConfig = ''
    Match User backup
      ForceCommand /run/current-system/sw/bin/bash -c 'exec rsync --server --sender -vlogDtpre.iLsfxC --read-only . ${lib.concatStringsSep " " stateDirs}'
      AllowTcpForwarding no
      PermitOpen none
      X11Forwarding no
  '';
}
