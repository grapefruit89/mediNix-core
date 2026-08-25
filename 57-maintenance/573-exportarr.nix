# ---
# id: "573-exportarr"
# title: "Exportarr — Prometheus Exporters for *arr Stack (per-instance)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links: 
# provides: []
# requires: ["lib/hardening-profiles"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5043
# skill: nixos-context7-gate
# context7: 
# - query: "systemd.services serviceConfig example"
# library: /websites/nixos_manual_nixos_unstable
# snippet: "systemd.services.<name> = { serviceConfig.ExecStart = ...; }"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.exporters;
  svc = config.medinix;

  # Arr services getting an exporter (Port = Service port + 1000)
  arrExporters = [
    { name = "sonarr";   port = 5320; }
    { name = "radarr";   port = 5330; }
    { name = "readarr";  port = 5340; }
    { name = "lidarr";   port = 5350; }
    { name = "prowlarr"; port = 5360; }
  ];

  mkExporter = e: lib.mkIf (cfg.enable && (svc.${e.name}.enable or false)) {
    systemd.services."exportarr-${e.name}" = {
      description = "Exportarr Prometheus Exporter for ${e.name}";
      after = [ "network-online.target" "${e.name}-${toString e.port}.service" ];
      requires = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = lib.mkMerge [
        # network-Profile: Go binary, port binding via CAP_NET_BIND_SERVICE
        (import ../lib/hardening-profiles.nix { inherit lib; }).network
        {
          ExecStart = "${pkgs.exportarr}/bin/exportarr ${e.name} --port ${toString (e.port + 1000)} --url http://127.0.0.1:${toString e.port}";
          User = "media";
          Group = "media";
          UMask = "002";
        }
      ];
    };
  };
in lib.mkMerge (map mkExporter arrExporters)
