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
  mkService = import ../lib/service-factory.nix { inherit lib config; };
  # .NET declarative settings via Env Vars (ersetzt curl-Provisioning)
  arrSettings = import ../lib/arr-settings.nix { inherit lib; };
in
{
  users.groups.media.gid = gid;

  # Prowlarr: indexiert nur, braucht SABnzbd nicht direkt (Arr holen sich von ihm)
  systemd.services.prowlarr = (mkService {
    name = "prowlarr";
    port = port;
    uid = uid;
    execStart = "${pkgs.prowlarr}/bin/Prowlarr -nobrowser -data=${stateDir}";
    stateDir = stateDir;
    profile = "dotnet";
    allowedPeers = [ "sabnzbd" ];
    extraConfig = {
      UMask          = "002";
      ReadWritePaths = [ stateDir ];
    };
  }).systemd.services.prowlarr // {
    after    = [ "network.target" ];
    requires = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = lib.mkMerge [
      (lib.mkIf (cfg.apiKeyFile != null) { PROWLARR_API_KEY_FILE = cfg.apiKeyFile; })
      (arrSettings.mkProwlarr {
        server = {
          port        = port;
          bindAddress = "127.0.0.1";
          urlBase     = "";
        };
        auth = {
          method   = "Forms";
          required = "Enabled";
        };
        app = {
          theme        = "dark";
          instanceName = "Prowlarr";
        };
        log.level        = "info";
        update.mechanism = "BuiltIn";
      })
    ];
  };

  systemd.sockets.prowlarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };
}
