# ---
# id: "597-maintenance-guardrails"
# title: "Maintenance & Backup Guardrails"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-5043
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  reg = import ./590-registry.nix { inherit lib; };
  # Alle State-Dirs die für Backup freigegeben sind (read-only)
  # Generiert primär dynamisch aus der Registry, plus manuelle Ausnahmen (ntfy-sh, recyclarr)
  registry = import ../lib/registry.nix { inherit lib; };
  registryDirs = lib.mapAttrsToList
    (_: svc: "/var/lib/${if svc.port != null then "${svc.name}-${toString svc.port}" else svc.name}")
    (lib.filterAttrs (n: _: n != "ntfy") registry.services);
  stateDirs = registryDirs ++ [ "/var/lib/ntfy-sh-5810" "/var/lib/recyclarr-5600" ];
in
lib.mkIf cfg.enable {
  assertions = [
    # STORE-003: sqlite.backup path muss outside of /nix/store sein
    (reg.mkErrorDoc "STORE-003"
      (let backupPath = cfg.maintenance.sqlite.backupDir;
       in !(lib.hasPrefix "/nix/store" backupPath))
      "5720")
  ];

  # Backup-SSH User Setup (früher 595-backup-ssh.nix)
  users.users.backup = lib.mkIf cfg.security.backupSsh.enable {
    isSystemUser = true;
    group = "backup";
    home = "/var/empty";
    shell = config.grapefruitMedia.security.backupSsh.shell;
    openssh.authorizedKeys.keys = config.grapefruitMedia.security.backupSsh.authorizedKeys;
  };
  users.groups.backup = lib.mkIf cfg.security.backupSsh.enable {};

  # SSH Restricted Command (nur rsync)
  services.openssh.extraConfig = lib.mkIf cfg.security.backupSsh.enable ''
    Match User backup
      ForceCommand rsync --server --sender -vlogDtprze.iLsfxCIvu . /
      AllowTcpForwarding no
      X11Forwarding no
      PermitTTY no
      PasswordAuthentication no
  '';

  # Polkit Rule (erlaubt systemd-run ohne Passwort für Backup-User)
  security.polkit.extraConfig = lib.mkIf cfg.security.backupSsh.enable ''
    polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "backup") {
            return polkit.Result.YES;
        }
    });
  '';

  # Nur read-only Mounts der Services
  systemd.services.rsync-backup = lib.mkIf cfg.security.backupSsh.enable {
    description = "Rsync Backup Service";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe config.grapefruitMedia.security.backupSsh.shell} -c 'rsync -avR ${lib.concatStringsSep " " stateDirs} /tmp/backup-dump'";
      User = "backup";
      ReadOnlyPaths = stateDirs;
    };
  };
}
