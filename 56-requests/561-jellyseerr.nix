# ---
# id: "561-jellyseerr"
# title: "Jellyseerr — Request Management (56-requests, Dienst 561)"
# domain: 56
# folder: 56-requests
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5610, ADR-5050
#   skill: nixos-context7-gate
#   repo-harvest: Fallenbagel/jellyseerr (Node.js, default port 5055 → 5610)
# context7:
#   - query: "systemd.services serviceConfig EnvironmentFile example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "services.shiori.environmentFile = \"/path/to/env-file\" (valid)"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.jellyseerr;
  svc = config.grapefruitMedia;
  port = 5610;  # 561 × 10
  uid  = 5610;
  gid  = 5000;
  stateDir = "/var/lib/jellyseerr-${toString port}";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in
{
  users.users.jellyseerr = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.jellyseerr = {
    after = [ "network-online.target" "jellyfin-5510.service" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      # .NET-Profil: MemoryDenyWriteExecute=false (JIT), PrivateDevices=true
      # SystemCallErrorNumber=EPERM kommt aus base-Profil (kein SIGSYS-Kill)
      profiles.dotnet
      {
        ExecStart = "${pkgs.jellyseerr}/bin/jellyseerr --port ${toString port} --host 127.0.0.1";
        User = "jellyseerr";
        Group = "media";
        UMask = "002";
        StateDirectory = "jellyseerr-${toString port}";
        ReadWritePaths = [ stateDir ];
        # caddyClass=public from registry → LAN+WAN, compression (handled by 511-caddy)
      }
    ];
    # Env-File via EnvironmentFile (ADR-5000: keine inline secrets)
    environmentFile = lib.mkIf (cfg.envFile != null) cfg.envFile;
  };
}
