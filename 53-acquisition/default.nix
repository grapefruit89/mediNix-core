# ---
# id: "default-acquisition"
# title: "*arr Suite Factory (Prowlarr/Sonarr/Radarr/Lidarr/Readarr)"
# domain: 50
# folder: 53-acquisition
# status: active
# complexity: 4
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-5043
# provides: ["mkArrService"]
# requires: ["lib/registry"]
# ports: [5310, 5320, 5330, 5340, 5350]
# upstream_docs: ["https://wiki.servarr.com/"]
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: "/var/lib"
# uds_socket: false
# systemd_hardened: true
# ---
# 53-acquisition/default.nix — *arr Suite Integration
{ lib, pkgs, config, ... }:

let
  cfg = config.grapefruitMedia;
  registry = import ../lib/registry.nix { inherit lib; };

  mkArrService = name: svc: {
    systemd.services.${name} = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = name;
        Group = "media";
        ExecStart = "${pkgs.${name}}/bin/${name} -data /var/lib/${name}";
        RestrictNetworkInterfaces = [ "lo" ];  # Isolation: Loopback only
        # State on Tier B (SSD), media on Tier C. No HDD WAL (see 536-sqlite-wal).
        ReadWritePaths = [ "/var/lib/${name}" cfg.storage.mediaRoot ];
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
    users.users.${name} = { group = "media"; isSystemUser = true; };
    users.groups.${name} = {};
  };
in
{
  config = lib.mkIf cfg.enable (lib.mapAttrsToList mkArrService registry);
}
