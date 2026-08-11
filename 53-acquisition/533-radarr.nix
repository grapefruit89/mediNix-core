# ---
# id: "533-radarr"
# title: "Radarr — Movie Management (53-acquisition, Dienst 533)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5320, ADR-5050
#   skill: nixos-context7-gate
# context7:
#   - query: "systemd.services serviceConfig NoNewPrivileges ProtectSystem example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "NoNewPrivileges=true, ProtectSystem=strict valid"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.radarr;
  svc = config.grapefruitMedia;
  port = 5330;
  uid  = 5330;
  gid  = 5000;
  stateDir = "/var/lib/radarr-${toString port}";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in
{
  users.users.radarr = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.radarr = {
    after    = [ "network-online.target" "prowlarr.service" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      profiles.dotnet
      {
        User           = "radarr";
        Group          = "media";
        ExecStart      = "${pkgs.radarr}/bin/Radarr -nobrowser -data=${stateDir}";
        StateDirectory = "radarr-${toString port}";
        UMask          = "002";
        ReadWritePaths = [ stateDir config.grapefruitMedia.storage.mediaRoot ];
      }
    ];
    environment = lib.mkMerge [
      (lib.mkIf (cfg.apiKeyFile != null) { RADARR_API_KEY_FILE = cfg.apiKeyFile; })
      (lib.mkIf svc.authProxyPresent { "AUTH__METHOD" = "External"; })
    ];
  };

  systemd.sockets.radarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };
}
