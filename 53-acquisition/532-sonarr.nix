# ---
# id: "532-sonarr"
# title: "Sonarr — Series Management (53-acquisition, Dienst 532)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5320, ADR-5050
#   skill: nixos-context7-gate
#   repo-harvest: Sonarr/Sonarr (sonarr.service: -data=/var/lib/sonarr, UMask=002)
# context7:
#   - query: "systemd.services serviceConfig NoNewPrivileges ProtectSystem example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "NoNewPrivileges=true, ProtectSystem=strict, MemoryDenyWriteExecute valid"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.sonarr;
  svc = config.grapefruitMedia;
  port = 5320;  # 532 × 10
  uid  = 5320;
  gid  = 5000;
  stateDir = "/var/lib/sonarr-${toString port}";
  mkService = import ../lib/service-factory.nix { inherit lib config; };
  # .NET declarative settings via Env Vars (ersetzt curl-Provisioning)
  arrSettings = import ../lib/arr-settings.nix { inherit lib; };
in
{
  users.groups.media.gid = gid;

  # Factory: dotnet-Profil (MemoryDenyWriteExecute=false, internet-Policy)
  # allowedPeers: Sonarr braucht SABnzbd (Download) + Prowlarr (Indexer)
  systemd.services.sonarr = (mkService {
    name = "sonarr";
    port = port;
    uid = uid;
    execStart = "${pkgs.sonarr}/bin/Sonarr -nobrowser -data=${stateDir}";
    stateDir = stateDir;
    profile = "dotnet";
    allowedPeers = [ "sabnzbd" "prowlarr" ];
    extraConfig = {
      User           = "sonarr";  # Factory setzt User=name, hier redundant sicher
      UMask          = "002";     # Arr-Stack braucht 002 für Gruppen-Schreibrechte
      ReadWritePaths = [ stateDir config.grapefruitMedia.storage.mediaRoot ];
    };
  }).systemd.services.sonarr // {
    after    = [ "network.target" "prowlarr.service" ];
    requires = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = lib.mkMerge [
      (lib.mkIf (cfg.apiKeyFile != null) { SONARR_API_KEY_FILE = cfg.apiKeyFile; })
      (arrSettings.mkSonarr {
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
          instanceName = "Sonarr";
        };
        log.level        = "info";
        update.mechanism = "BuiltIn";  # Nix managed Updates, nicht die App
      })
    ];
  };

  systemd.sockets.sonarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };
}
