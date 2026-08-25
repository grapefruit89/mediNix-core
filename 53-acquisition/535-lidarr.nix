# ---
# id: "535-lidarr"
# title: "Lidarr — Music Download Manager (53-acquisition, Service 535)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links: 
# provides: []
# requires: ["lib/registry"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5320, ADR-5050
# context7: 
# - query: "systemd.services serviceConfig ProtectSystem example"
# library: /websites/nixos_manual_nixos_unstable
# ---

{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.lidarr;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.lidarr;
  port = reg.port;
  uid = reg.uid;
  gid = reg.gid;
  stateDir = reg.stateDir;
  mkService = import ../lib/service-factory.nix { inherit lib config; };
  # .NET declarative settings via Env Vars (replaces curl provisioning)
  arrSettings = import ../lib/arr-settings.nix { inherit lib; };
in
lib.mkIf cfg.enable (lib.mkMerge [ {
  users.groups.media.gid = gid;

  } (mkService {
    name = "lidarr";
    port = port;
    uid = uid;
    execStart = "${pkgs.lidarr}/bin/Lidarr -nobrowser -data=${stateDir}";
    stateDir = stateDir;
    profile = "dotnet";
    allowedPeers = [ "sabnzbd" "prowlarr" ];
    extraConfig = {
      UMask          = "0002";
      ReadWritePaths = [ stateDir config.medinix.storage.mediaRoot ];
    };
  })
  {
    systemd.services.lidarr = {
    after    = [ "network.target" "prowlarr.service" ];
    requires = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = lib.mkMerge [
      (lib.mkIf (svc.secrets.lidarrApiKeyFile or null != null) { LIDARR_API_KEY_FILE = svc.secrets.lidarrApiKeyFile; })
      (arrSettings.mkLidarr {
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
          instanceName = "Lidarr";
        };
        log.level        = "info";
        update.mechanism = "BuiltIn";
      })
    ];
  };

  systemd.sockets.lidarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };

  medinix.ingress.vhosts."lidarr" = { accessGroup = reg.caddyClass; };

  } { systemd.services."lidarr" = lib.mkIf (svc.secrets.lidarrApiKeyFile != null) {
    serviceConfig.LoadCredentialEncrypted = [ "lidarr-api-key:${svc.secrets.lidarrApiKeyFile}" ];
  };

} ])
