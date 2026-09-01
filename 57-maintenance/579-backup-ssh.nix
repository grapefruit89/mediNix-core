# ---
# id: "579-backup-ssh"
# title: "SSH pull user for A2 state (no local dump)"
# domain: 57
# folder: 57-maintenance
# status: active
# last_reviewed: 2026-09-02
# requires: ["lib/registry"]
# adr: ADR-576
# ---
# Optional pull path next to 576 restic. Encryption is SSH, not a second restic.
# Never write an unencrypted tree under /tmp.
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.security.backupSsh;
  registry = import ../lib/registry.nix { inherit lib; };
  stateful = lib.filterAttrs (_: s: s.stateDir != null) registry.services;
  units = lib.mapAttrsToList (_: s: "${s.unitName}.service") stateful;
  unitList = lib.concatMapStringsSep ", " (u: "\"${u}\"") units;
in
lib.mkIf cfg.enable {
  users.users.backup = {
    isNormalUser = true;
    extraGroups = [ "media" ];
    openssh.authorizedKeys.keys = cfg.sshKeys;
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
}
