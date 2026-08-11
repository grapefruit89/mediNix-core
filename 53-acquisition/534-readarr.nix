# ---
# id: "534-readarr"
# title: "Readarr — Book Management (53-acquisition, Dienst 534)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5040
#   skill: nixos-context7-gate
# context7:
#   - query: "systemd.services serviceConfig ProtectSystem StateDirectory example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "same native pattern as Sonarr"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.readarr;
  svc = config.grapefruitMedia;
  port = 5340;  # 534 × 10
  uid  = 5340;
  gid  = 5000;
in
{
  users.users.readarr = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = "/var/lib/readarr-${toString port}"; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.readarr = {
    after = [ "network-online.target" "prowlarr.service" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.readarr}/bin/Readarr -nobrowser -data=/var/lib/readarr-${toString port}";
      User = "readarr"; Group = "media"; UMask = "002";
      ProtectSystem = "strict"; ProtectHome = true; PrivateTmp = true; NoNewPrivileges = true;
      StateDirectory = "readarr-${toString port}";
      ReadWritePaths = [ "/var/lib/readarr-${toString port}" config.grapefruitMedia.storage.mediaRoot ];
    };
    environment = lib.mkMerge [
      (lib.mkIf (cfg.apiKeyFile != null) { READARR_API_KEY_FILE = cfg.apiKeyFile; })
      (lib.mkIf svc.authProxyPresent { "AUTH__METHOD" = "External"; })
    ];
  };

  systemd.sockets.readarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };
}
