# ---
# id: "593-emergency-user"
# title: "media-admin Emergency User — restricted sudo for service restarts only"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-21-security-hardening
# provides: []
# requires: ["593-no-password-auth"]
# ports: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.security.emergencyUser;
in lib.mkIf cfg.enable {
  users.users.media-admin = {
    isNormalUser = true;
    uid = 5800;  # media-admin (58 = observability/ops, 00 = admin)
    group = "media";
    extraGroups = [ "media" "wheel" ];
    openssh.authorizedKeys.keys = cfg.sshKeys;
    shell = pkgs.bash;
  };
  users.groups.media.gid = 5000;

  # Eingeschränktes sudo: NUR systemctl restart der mediNix-Services
  security.sudo.extraConfig = ''
    %media-admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl restart jellyfin-5510.service, \
                                           /run/current-system/sw/bin/systemctl restart sabnzbd-5410.service, \
                                           /run/current-system/sw/bin/systemctl restart sonarr-5320.service, \
                                           /run/current-system/sw/bin/systemctl restart radarr-5330.service, \
                                           /run/current-system/sw/bin/systemctl restart prowlarr-5360.service, \
                                           /run/current-system/sw/bin/systemctl restart jellyseerr-5610.service, \
                                           /run/current-system/sw/bin/systemctl restart ntfy-5810.service
    %media-admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl status *
  '';
}
