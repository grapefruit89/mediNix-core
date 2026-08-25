# ---
# id: "520-core-security"
# title: "Core Security: Media Group, Emergency Admin User & Restricted Sudo"
# domain: 52
# folder: 52-security
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

{ config, lib, ... }:

let
  cfg = config.medinix.security.emergencyUser;
in
{
  config = lib.mkMerge [
    (lib.mkIf config.medinix.enable {
      # Central media group and user (Unconditional within media stack)
      users.groups.media.gid = 5000;
      users.users.media = {
        isSystemUser = true;
        group = "media";
      };
    })
    (lib.mkIf cfg.enable {
  # 2. Create Emergency User (media-admin)
  users.users.media-admin = {
    isNormalUser = true;
    extraGroups = [ "media" ];
    openssh.authorizedKeys.keys = cfg.sshKeys;
  };

  # 3. Restricted Sudo Rights (no root shell, only service restarts + status)
  security.sudo.extraConfig =
    let
      registry = import ../lib/registry.nix { inherit lib; };
      restartCmds = lib.mapAttrsToList
        (_: svc: "/run/current-system/sw/bin/systemctl restart ${svc.unitName}.service")
        registry.services;
      cmdString = lib.concatStringsSep ", \\\n                                           " restartCmds;
    in ''
      media-admin ALL=(root) NOPASSWD: ${cmdString}
      media-admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl status * --no-pager
    '';
})
  ];
}
