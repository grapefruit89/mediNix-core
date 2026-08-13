# ---
# id: "523-emergency-user"
# title: "Emergency User (media-admin) Configuration"
# domain: 52
# folder: 52-security
# status: active
# complexity: 2
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-0000
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia.security.emergencyUser;
in
lib.mkIf cfg.enable {
  # 1. GID 5000 = media
  users.groups.media.gid = 5000;

  # 2. Emergency User anlegen (media-admin)
  users.users.media-admin = {
    isNormalUser = true;
    extraGroups = [ "media" ];
    openssh.authorizedKeys.keys = cfg.sshKeys;
  };

  # 3. Eingeschränkte Sudo-Rechte (kein Root-Shell, nur Service-Restarts + Status)
  security.sudo.extraConfig =
    let
      registry = import ../lib/registry.nix { inherit lib; };
      restartCmds = lib.mapAttrsToList
        (_: svc: "/run/current-system/sw/bin/systemctl restart ${if svc.port != null then "${svc.name}-${toString svc.port}" else svc.name}.service")
        registry.services;
      cmdString = lib.concatStringsSep ", \\\n                                           " restartCmds;
    in ''
      media-admin ALL=(root) NOPASSWD: ${cmdString}
      media-admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl status *
    '';
}
