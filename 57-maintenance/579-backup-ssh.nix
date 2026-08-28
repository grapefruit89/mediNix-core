# ---
# id: "579-backup-ssh"
# title: "Backup SSH User Configuration"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 2
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
# adr: ADR-0000
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

  # Polkit rule for systemctl (stop services during backup).
  # ADR-5721: scoped down from blanket manage-units (previously: ANY systemd
  # unit) to exactly the media-app services 576-backup.nix stops/starts for
  # DB-safety. Keep this list in sync with `mediaServices` in
  # 57-maintenance/576-backup.nix (documented as a known gap in ADR-5721 --
  # a shared list in lib/registry.nix would remove the duplication).
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var allowedUnits = [
        "sonarr.service", "radarr.service", "prowlarr.service", "lidarr.service",
        "readarr.service", "sabnzbd.service", "jellyfin.service",
        "audiobookshelf.service", "navidrome.service"
      ];
      if (action.id == "org.freedesktop.systemd1.manage-units" && subject.user == "backup") {
        var unit = action.lookup("unit");
        if (allowedUnits.indexOf(unit) !== -1) {
          return polkit.Result.YES;
        }
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
