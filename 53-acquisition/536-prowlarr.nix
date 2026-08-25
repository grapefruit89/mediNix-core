# ---
# id: "536-prowlarr"
# title: "Prowlarr — Indexer Manager (53-acquisition, Service 536)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
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
# context7: 
# - query: "systemd.services serviceConfig ProtectSystem example"
# library: /websites/nixos_manual_nixos_unstable
# ---
# WARNING (CRITICAL): PROWLARR MUST NEVER GO THROUGH THE VPN!
# Indexers heavily block, ban, or throw Captchas at known VPN IP addresses.
# Routing Prowlarr through a VPN will break search and indexer sync.
# DO NOT add services.vpnKillSwitch confinement to this file.

{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.prowlarr;
  svc = config.medinix;
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
lib.mkIf cfg.enable (lib.mkMerge [ {
  users.groups.media.gid = gid;

  # Prowlarr: only indexes, doesn't need SABnzbd directly (Arr fetch from it)
  } (mkService {
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
  })
  {
    systemd.services.prowlarr = {
    after    = [ "network.target" ];
    requires = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = lib.mkMerge [
      (lib.mkIf (svc.secrets.prowlarrApiKeyFile or null != null) { PROWLARR_API_KEY_FILE = svc.secrets.prowlarrApiKeyFile; })
      (arrSettings.mkProwlarr {
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

  medinix.ingress.vhosts."prowlarr" = { accessGroup = reg.caddyClass; };

  }
  {
    systemd.services."prowlarr" = lib.mkIf (svc.secrets.prowlarrApiKeyFile or null != null) {
      serviceConfig.LoadCredentialEncrypted = [ "prowlarr-api-key:${svc.secrets.prowlarrApiKeyFile}" ];
    };
  }
])
