# ---
# id: "535-lidarr"
# title: "Lidarr — Music Download Manager (53-acquisition, Dienst 535)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5320, ADR-5050
# context7:
#   - query: "systemd.services serviceConfig ProtectSystem example"
#     library: /websites/nixos_manual_nixos_unstable
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.lidarr;
  svc = config.grapefruitMedia;
  port = 5350;
  uid  = 5350;
  gid  = 5000;
  stateDir = "/var/lib/lidarr-${toString port}";
  mkService = import ../lib/service-factory.nix { inherit lib config; };
in
{
  users.groups.media.gid = gid;

  systemd.services.lidarr = (mkService {
    name = "lidarr";
    port = port;
    uid = uid;
    execStart = "${pkgs.lidarr}/bin/Lidarr -nobrowser -data=${stateDir}";
    stateDir = stateDir;
    profile = "dotnet";
    allowedPeers = [ "sabnzbd" "prowlarr" ];
    extraConfig = {
      UMask          = "002";
      ReadWritePaths = [ stateDir config.grapefruitMedia.storage.mediaRoot ];
    };
  }).systemd.services.lidarr // {
    after    = [ "network-online.target" "prowlarr.service" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
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
