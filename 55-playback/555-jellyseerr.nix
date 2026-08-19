# ---
# id: "555-jellyseerr"
# title: "Jellyseerr — Request Management (55-playback, Service 555)"
# domain: 55
# folder: 55-playback
# status: active
# complexity: 3
# last_reviewed: 2026-08-18
# links:
#   adr: ADR-5610, ADR-5050
#   skill: nixos-context7-gate
#   repo-harvest: Fallenbagel/jellyseerr (Node.js, default port 5055 → 5550)
# context7:
#   - query: "systemd.services serviceConfig EnvironmentFile example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "services.shiori.environmentFile = \"/path/to/env-file\" (valid)"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.jellyseerr;
  svc = config.grapefruitMedia;
  port = 5550;  # 555 × 10
  uid  = 5550;
  gid  = 5000;
  stateDir = "/var/lib/jellyseerr-${toString port}";
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
        ExecStart = "${pkgs.jellyseerr}/bin/jellyseerr --port ${toString port} --host 127.0.0.1";
        User = "jellyseerr";
        Group = "media";
        UMask = lib.mkForce "0002";
        StateDirectory = "jellyseerr-${toString port}";
        ReadWritePaths = [ stateDir ];
        # caddyClass=public from registry → LAN+WAN, compression (handled by 511-caddy)
      }
      (lib.mkIf (cfg.envFile or null != null) {
        EnvironmentFile = cfg.envFile;
      })
    ];
    # .NET declarative settings (Port/Bind/Auth) via Env Vars
    environment = arrSettings.mkJellyseerr {
      server = {
        port        = port;
        bindAddress = "127.0.0.1";
        urlBase     = "";
      };
      auth = {
        method   = if svc.authProxyPresent then "External" else "Forms";
        required = "Enabled";
      };
      app = {
        theme        = "dark";
        instanceName = "Jellyseerr";
      };
      log.level        = "info";
      update.mechanism = "BuiltIn";
    };
  };

  grapefruitMedia.ingress.vhosts."jellyseerr" = { accessGroup = "public"; };

  grapefruitMedia.ingress.vhosts."jellyseerr" = { accessGroup = "public"; };
}

