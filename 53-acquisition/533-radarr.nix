# ---
# id: "533-radarr"
# title: "Radarr — Movie Management (53-acquisition, Dienst 533)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5040
#   skill: nixos-context7-gate
#   repo-harvest: Radarr/Radarr (.NET6 EOL analog Sonarr; #10819 GER/DE parser fix)
# context7:
#   - query: "systemd.services serviceConfig ProtectSystem StateDirectory example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "StateDirectory + ProtectSystem=strict (same as Sonarr pattern)"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.radarr;
  svc = config.grapefruitMedia;
  port = 5330;  # 533 × 10
  uid  = 5330;
  gid  = 5000;
in
{
  users.users.radarr = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = "/var/lib/radarr-${toString port}"; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.radarr = {
    after = [ "network-online.target" "prowlarr.service" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.radarr}/bin/Radarr -nobrowser -data=/var/lib/radarr-${toString port}";
      User = "radarr"; Group = "media"; UMask = "002";
      ProtectSystem = "strict"; ProtectHome = true; PrivateTmp = true; NoNewPrivileges = true;
      StateDirectory = "radarr-${toString port}";
      ReadWritePaths = [ "/var/lib/radarr-${toString port}" config.grapefruitMedia.storage.mediaRoot ];
    };
    environment = lib.mkMerge [
      (lib.mkIf (cfg.apiKeyFile != null) { RADARR_API_KEY_FILE = cfg.apiKeyFile; })
      (lib.mkIf svc.authProxyPresent { "AUTH__METHOD" = "External"; })
    ];
  };

  systemd.sockets.radarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };
}
