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
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in
{
  users.users.sonarr = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.sonarr = {
    after    = [ "network-online.target" "prowlarr.service" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      # Zentrales .NET-Hardening-Profil (ADR-5050) — keine per-Modul Duplikate
      profiles.dotnet
      {
        User           = "sonarr";
        Group          = "media";
        ExecStart      = "${pkgs.sonarr}/bin/Sonarr -nobrowser -data=${stateDir}";
        StateDirectory = "sonarr-${toString port}";
        UMask          = "002";
        ReadWritePaths = [ stateDir config.grapefruitMedia.storage.mediaRoot ];
      }
    ];
    environment = lib.mkMerge [
      (lib.mkIf (cfg.apiKeyFile != null) { SONARR_API_KEY_FILE = cfg.apiKeyFile; })
      (lib.mkIf svc.authProxyPresent { "AUTH__METHOD" = "External"; })
    ];
  };

  systemd.sockets.sonarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };
}
