# ---
# id: "536-prowlarr"
# title: "Prowlarr — Indexer Manager (53-acquisition, Dienst 536)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5040
#   skill: nixos-context7-gate
#   repo-harvest: Prowlarr/Prowlarr (README, issues #2506 .NET9, #2608 open-redirect)
# context7:
#   - query: "systemd.services serviceConfig ProtectSystem StateDirectory example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "systemd.services.<name>.serviceConfig.ProtectSystem/StateDirectory/ReadWritePaths"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.prowlarr;
  svc = config.grapefruitMedia;
  port = 5360;  # ADR-0000 §4: 536 × 10
  uid  = 5360;  # isomorph: UID = Port
  gid  = 5000;  # GID = Projekt × 1000
in
{
  # User/Group (isomorph, ADR-0000 §4)
  users.users.prowlarr = {
    uid = uid;
    group = "media";
    extraGroups = [ "media" ];
    home = "/var/lib/prowlarr-${toString port}";
    isSystemUser = true;
  };
  users.groups.media.gid = gid;

  # Native systemd service (kein Docker, ADR-5000)
  systemd.services.prowlarr = {
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.prowlarr}/bin/Prowlarr -nobrowser -data=/var/lib/prowlarr-${toString port}";
      User = "prowlarr";
      Group = "media";
      UMask = "002";
      # Hardening (ADR-5050)
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      StateDirectory = "prowlarr-${toString port}";
      ReadWritePaths = [ "/var/lib/prowlarr-${toString port}" ];
      # Bind nur auf Loopback — nie 0.0.0.0 (ADR-5110)
      # Prowlarr liest Bind-Adresse aus config.xml, default 127.0.0.1
    };
    # API-Key via EnvironmentFile (ADR-5000: keine inline secrets)
    environment = lib.mkIf (cfg.apiKeyFile != null) {
      PROWLARR_API_KEY_FILE = cfg.apiKeyFile;
    };
  };

  # OnDemand-Socket wenn gewünscht (ADR-onDemand)
  systemd.sockets.prowlarr = lib.mkIf svc.onDemand.enable {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString port}" ];
    socketConfig.Accept = false;
  };
}
