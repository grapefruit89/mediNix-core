# ---
# id: "534-readarr"
# title: "Readarr — Book Management (53-acquisition, Dienst 534)"
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
  cfg = config.grapefruitMedia.services.readarr;
  svc = config.grapefruitMedia;
  port = 5340;
  uid  = 5340;
  gid  = 5000;
  stateDir = "/var/lib/readarr-${toString port}";
  mkService = import ../lib/service-factory.nix { inherit lib config; };
in
{
  users.groups.media.gid = gid;

  systemd.services.readarr = (mkService {
    name = "readarr";
    port = port;
    uid = uid;
    execStart = "${pkgs.readarr}/bin/Readarr -nobrowser -data=${stateDir}";
    stateDir = stateDir;
    profile = "dotnet";
    allowedPeers = [ "sabnzbd" "prowlarr" ];
    extraConfig = {
      UMask          = "002";
      ReadWritePaths = [ stateDir config.grapefruitMedia.storage.mediaRoot ];
    };
  }).systemd.services.readarr // {
    after    = [ "network-online.target" "prowlarr.service" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = lib.mkMerge [
      (lib.mkIf (cfg.apiKeyFile != null) { READARR_API_KEY_FILE = cfg.apiKeyFile; })
      (lib.mkIf svc.authProxyPresent { "AUTH__METHOD" = "External"; })
    ];
  };

  systemd.sockets.readarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };
}
