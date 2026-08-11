# ---
# id: "532-sonarr"
# title: "Sonarr — Series Management (53-acquisition, Dienst 532)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5320
#   skill: nixos-context7-gate
#   repo-harvest: Sonarr/Sonarr (sonarr.service: -data=/var/lib/sonarr, UMask=002; issues #7442/.NET6 EOL, #7686 remote-path perms)
# context7:
#   - query: "systemd.services serviceConfig ProtectSystem StateDirectory example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "StateDirectory + ProtectSystem=strict + ReadWritePaths"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.sonarr;
  svc = config.grapefruitMedia;
  port = 5320;  # 532 × 10
  uid  = 5320;
  gid  = 5000;
in
{
  users.users.sonarr = {
    uid = uid;
    group = "media";
    extraGroups = [ "media" ];
    home = "/var/lib/sonarr-${toString port}";
    isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.sonarr = {
    after = [ "network-online.target" "prowlarr.service" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.sonarr}/bin/Sonarr -nobrowser -data=/var/lib/sonarr-${toString port}";
      User = "sonarr";
      Group = "media";
      UMask = "002";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      StateDirectory = "sonarr-${toString port}";
      ReadWritePaths = [ "/var/lib/sonarr-${toString port}" config.grapefruitMedia.storage.mediaRoot ];
      # AUTH: External wenn Auth-Proxy present (Pocket ID / Caddy forward-auth)
      # Sonarr liest AUTH__METHOD aus env (Servarr-Pattern)
    };
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
