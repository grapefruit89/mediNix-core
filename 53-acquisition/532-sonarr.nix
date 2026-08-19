# ---
# id: "532-sonarr"
# title: "Sonarr — Series Management (53-acquisition, Service 532)"
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
  cfg = config.grapefruitMedia.sonarr;
  svc = config.grapefruitMedia;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.sonarr;
  port = reg.port;
  uid = reg.uid;
  gid = reg.gid;
  stateDir = reg.stateDir;
  mkService = import ../lib/service-factory.nix { inherit lib config; };
  # .NET declarative settings via Env Vars (replaces curl provisioning)
  arrSettings = import ../lib/arr-settings.nix { inherit lib; };
in
lib.mkIf cfg.enable {
  users.groups.media.gid = gid;

  # Factory: dotnet profile (MemoryDenyWriteExecute=false, internet-Policy)
  # allowedPeers: Sonarr needs SABnzbd (Download) + Prowlarr (Indexer)
  systemd.services.sonarr = (mkService {
    name = "sonarr";
    port = port;
    uid = uid;
    execStart = "${pkgs.sonarr}/bin/Sonarr -nobrowser -data=${stateDir}";
    stateDir = stateDir;
    profile = "dotnet";
    allowedPeers = [ "sabnzbd" "prowlarr" ];
    extraConfig = {
      User           = "sonarr";  # Factory sets User=name, here redundant but safe
      UMask          = "0002";     # Arr-Stack needs 002 for group write permissions
      ReadWritePaths = [ stateDir config.grapefruitMedia.storage.mediaRoot ];
    };
  }).systemd.services.sonarr // {
    after    = [ "network.target" "prowlarr.service" ];
    requires = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = lib.mkMerge [
      (lib.mkIf (cfg.apiKeyFile or null != null) { SONARR_API_KEY_FILE = cfg.apiKeyFile; })
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
        update.mechanism = "BuiltIn";  # Nix manages Updates, not the App
      })
    ];
  };

  systemd.sockets.sonarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };

  grapefruitMedia.ingress.vhosts."sonarr" = { accessGroup = reg.caddyClass; };
}

