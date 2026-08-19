# ---
# id: "533-radarr"
# title: "Radarr — Movie Management (53-acquisition, Service 533)"
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
  cfg = config.grapefruitMedia.radarr;
  svc = config.grapefruitMedia;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.radarr;
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

  systemd.services.radarr = (mkService {
    name = "radarr";
    port = port;
    uid = uid;
    execStart = "${pkgs.radarr}/bin/Radarr -nobrowser -data=${stateDir}";
    stateDir = stateDir;
    profile = "dotnet";
    allowedPeers = [ "sabnzbd" "prowlarr" ];
    extraConfig = {
      UMask          = "0002";
      ReadWritePaths = [ stateDir config.grapefruitMedia.storage.mediaRoot ];
    };
  }).systemd.services.radarr // {
    after    = [ "network.target" "prowlarr.service" ];
    requires = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = lib.mkMerge [
      (lib.mkIf (cfg.apiKeyFile or null != null) { RADARR_API_KEY_FILE = cfg.apiKeyFile; })
      (arrSettings.mkRadarr {
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
          instanceName = "Radarr";
        };
        log.level        = "info";
        update.mechanism = "BuiltIn";
      })
    ];
  };

  systemd.sockets.radarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };

  grapefruitMedia.ingress.vhosts."radarr" = { accessGroup = reg.caddyClass; };

  systemd.services."radarr" = lib.mkIf (cfg.secrets.radarrApiKeyFile != null) {
    serviceConfig.LoadCredentialEncrypted = [ "radarr-api-key:${cfg.secrets.radarrApiKeyFile}" ];
  };

}
