# ---
# id: "579-backup-ssh"
# title: "Backup SSH User Configuration"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 2
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-0000
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.security.backupSsh;
  mediaConfig = config.medinix;
  registry = import ../lib/registry.nix { inherit lib; };
  stateDirs = lib.mapAttrsToList (_: svc: svc.stateDir) registry.services;
  dbDirs = lib.filter (d: d != "") stateDirs;
in
lib.mkIf cfg.enable {
  users.users.backup = {
    isNormalUser = true;
    extraGroups = [ "media" ];
    openssh.authorizedKeys.keys = cfg.sshKeys;
  };

  # SSH Lockdown for Backup-User
  services.openssh.extraConfig = ''
    Match User backup
      AllowTcpForwarding no
      X11Forwarding no
      PermitTTY no
      ForceCommand ${pkgs.rsync}/bin/rsync --server --sender -vlogDtprze.iLsfxCIvu . /var/lib/
  '';

  # Polkit rule for systemctl (stop services during backup)
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" && subject.user == "backup") {
        return polkit.Result.YES;
      }
    });
  '';

  # Only read-only mounts of the services
  systemd.services.rsync-backup = {
    description = "Rsync Backup Service";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.bash} -c 'rsync -avR ${lib.concatStringsSep " " stateDirs} /tmp/backup-dump'";
      User = "backup";
      ReadOnlyPaths = stateDirs;
    };
  };
}
