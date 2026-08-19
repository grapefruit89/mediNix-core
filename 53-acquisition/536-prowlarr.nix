# ---
# id: "536-prowlarr"
# title: "Prowlarr — Indexer Manager (53-acquisition, Service 536)"
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
# WARNING (CRITICAL): PROWLARR MUST NEVER GO THROUGH THE VPN!
# Indexers heavily block, ban, or throw Captchas at known VPN IP addresses.
# Routing Prowlarr through a VPN will break search and indexer sync.
# DO NOT add services.vpnKillSwitch confinement to this file.

{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.prowlarr;
  svc = config.grapefruitMedia;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.prowlarr;
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

  # Prowlarr: only indexes, doesn't need SABnzbd directly (Arr fetch from it)
  systemd.services.prowlarr = (mkService {
    name = "prowlarr";
    port = port;
    uid = uid;
    execStart = "${pkgs.prowlarr}/bin/Prowlarr -nobrowser -data=${stateDir}";
    stateDir = stateDir;
    profile = "dotnet";
    allowedPeers = [ "sabnzbd" ];
    extraConfig = {
      UMask          = "0002";
      ReadWritePaths = [ stateDir ];
    };
  }).systemd.services.prowlarr // {
    after    = [ "network.target" ];
    requires = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = lib.mkMerge [
      (lib.mkIf (cfg.apiKeyFile or null != null) { PROWLARR_API_KEY_FILE = cfg.apiKeyFile; })
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

  grapefruitMedia.ingress.vhosts."prowlarr" = { accessGroup = reg.caddyClass; };

  systemd.services."prowlarr" = lib.mkIf (cfg.secrets.prowlarrApiKeyFile != null) {
    serviceConfig.LoadCredentialEncrypted = [ "prowlarr-api-key:${cfg.secrets.prowlarrApiKeyFile}" ];
  };

  };

}
