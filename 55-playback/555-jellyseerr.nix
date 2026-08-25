# ---
# id: "555-jellyseerr"
# title: "Jellyseerr — Request Management (55-playback, Service 555)"
# domain: 55
# folder: 55-playback
# status: active
# complexity: 3
# last_reviewed: 2026-08-18
# links: 
# provides: []
# requires: ["lib/arr-settings", "lib/hardening-profiles", "lib/registry"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5610, ADR-5050
# skill: nixos-context7-gate
# repo-harvest: Fallenbagel/jellyseerr (Node.js, default port 5055 → 5550)
# context7: 
# - query: "systemd.services serviceConfig EnvironmentFile example"
# library: /websites/nixos_manual_nixos_unstable
# snippet: "services.shiori.environmentFile = \"/path/to/env-file\" (valid)"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.jellyseerr;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.jellyseerr;
  port = reg.port;
  uid = reg.uid;
  gid = reg.gid;
  stateDir = reg.stateDir;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  # .NET declarative settings via Env Vars (replaces curl provisioning)
  arrSettings = import ../lib/arr-settings.nix { inherit lib; };
in
lib.mkIf (cfg.enable) {
  users.users.jellyseerr = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.jellyseerr = {
    after = [ "network.target" "jellyfin-5510.service" ];
    requires = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      # .NET profile: MemoryDenyWriteExecute=false (JIT), PrivateDevices=true
      # SystemCallErrorNumber=EPERM comes from base profile (no SIGSYS kill)
      profiles.dotnet
      {
        ExecStart = "${pkgs.jellyseerr or pkgs.overseerr}/bin/jellyseerr";
        User = "jellyseerr";
        Group = "media";
        UMask = "0002";
        StateDirectory = "jellyseerr-${toString port}";
        ReadWritePaths = [ stateDir ];
        # caddyClass=public from registry → LAN+WAN, compression (handled by 511-caddy)
      }
      (lib.mkIf (cfg.envFile or null != null) {
        EnvironmentFile = cfg.envFile;
      })
      (lib.mkIf (svc.secrets.jellyseerrApiKeyFile or null != null) {
        LoadCredentialEncrypted = [ "jellyseerr-api-key:${svc.secrets.jellyseerrApiKeyFile}" ];
      })
    ];
    environment = {
      PORT = toString port;
      HOST = "127.0.0.1";
    };
  };

  medinix.ingress.vhosts."jellyseerr" = { accessGroup = reg.caddyClass; };


}
