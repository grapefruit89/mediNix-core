# ---
# id: "536-prowlarr"
# title: "Prowlarr — Indexer Manager (53-acquisition, Dienst 536)"
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
  cfg = config.grapefruitMedia.services.prowlarr;
  svc = config.grapefruitMedia;
  port = 5360;
  uid  = 5360;
  gid  = 5000;
  stateDir = "/var/lib/prowlarr-${toString port}";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in
{
  users.users.prowlarr = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.prowlarr = {
    after    = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      profiles.dotnet
      {
        User           = "prowlarr";
        Group          = "media";
        ExecStart      = "${pkgs.prowlarr}/bin/Prowlarr -nobrowser -data=${stateDir}";
        StateDirectory = "prowlarr-${toString port}";
        UMask          = "002";
        ReadWritePaths = [ stateDir ];
      }
    ];
    environment = lib.mkMerge [
      (lib.mkIf (cfg.apiKeyFile != null) { PROWLARR_API_KEY_FILE = cfg.apiKeyFile; })
      (lib.mkIf svc.authProxyPresent { "AUTH__METHOD" = "External"; })
    ];
  };

  systemd.sockets.prowlarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };
}
