# ---
# id: "535-lidarr"
# title: "Lidarr — Music Management (53-acquisition, Dienst 535)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5040
#   skill: nixos-context7-gate
# context7:
#   - query: "systemd.services serviceConfig ProtectSystem StateDirectory example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "same native pattern as Sonarr"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.lidarr;
  svc = config.grapefruitMedia;
  port = 5350;  # 535 × 10
  uid  = 5350;
  gid  = 5000;
in
{
  users.users.lidarr = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = "/var/lib/lidarr-${toString port}"; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.lidarr = {
    after = [ "network-online.target" "prowlarr.service" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.lidarr}/bin/Lidarr -nobrowser -data=/var/lib/lidarr-${toString port}";
      User = "lidarr"; Group = "media"; UMask = "002";
      ProtectSystem = "strict"; ProtectHome = true; PrivateTmp = true; NoNewPrivileges = true;
      StateDirectory = "lidarr-${toString port}";
      ReadWritePaths = [ "/var/lib/lidarr-${toString port}" config.grapefruitMedia.storage.mediaRoot ];
    };
    environment = lib.mkMerge [
      (lib.mkIf (cfg.apiKeyFile != null) { LIDARR_API_KEY_FILE = cfg.apiKeyFile; })
      (lib.mkIf svc.authProxyPresent { "AUTH__METHOD" = "External"; })
    ];
  };

  systemd.sockets.lidarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };
}
