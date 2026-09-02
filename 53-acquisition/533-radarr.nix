# ---
# id: "533-radarr"
# title: "Radarr — Movie Management (53-acquisition, Service 533)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# logo: https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/radarr.svg
# links: 
# provides: []
# requires: ["lib/arr-settings", "lib/service-factory", "lib/registry"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5320, ADR-5050
# skill: nixos-context7-gate
# context7: 
# - query: "systemd.services serviceConfig NoNewPrivileges ProtectSystem example"
# library: /websites/nixos_manual_nixos_unstable
# snippet: "NoNewPrivileges=true, ProtectSystem=strict valid"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.radarr;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.radarr;
  port = reg.port;
  uid = reg.uid;
  gid = reg.gid;
  stateDir = reg.stateDir;
  mkService = import ../lib/service-factory.nix { inherit lib config; };
  arrSettings = import ../lib/arr-settings.nix { inherit lib; };
in
lib.mkIf cfg.enable (lib.mkMerge [ {
  users.groups.media.gid = gid;

  } (mkService {
    name = "radarr";
    port = port;
    uid = uid;
    execStart = "${pkgs.radarr}/bin/Radarr -nobrowser -data=${stateDir}";
    stateDir = stateDir;
    profile = "dotnet";
    allowedPeers = [ "sabnzbd" "prowlarr" ];
    extraConfig = {
      UMask          = "0002";
      ReadWritePaths = [ stateDir config.medinix.storage.mediaRoot ];
    };
  })
  {
    systemd.services.radarr = {
    after    = [ "network.target" "prowlarr.service" ];
    requires = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = lib.mkMerge [
      (lib.mkIf (svc.secrets.radarrApiKeyFile or null != null) { RADARR_API_KEY_FILE = svc.secrets.radarrApiKeyFile; })
      (arrSettings.mkRadarr {
        server = {
          port        = port;
          bindAddress = "127.0.0.1";
          urlBase     = "";
        };
        auth = {
          method   = if config.medinix.ingress.auth.mode == "forward-auth" then "External" else "Forms";
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

  medinix.ingress.vhosts."radarr" = { accessGroup = reg.caddyClass; };

  } { systemd.services."radarr" = lib.mkIf (svc.secrets.radarrApiKeyFile != null) {
    serviceConfig.LoadCredentialEncrypted = [ "radarr-api-key:${svc.secrets.radarrApiKeyFile}" ];
  };

} ])
