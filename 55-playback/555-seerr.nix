# ---
# id: "555-seerr"
# title: "Seerr — Request Management (55-playback, Service 555)"
# domain: 55
# folder: 55-playback
# status: active
# complexity: 3
# last_reviewed: 2026-08-18
# links: https://seerr.dev/, https://github.com/seerr-team/seerr
# provides: []
# requires: ["lib/hardening-profiles", "lib/registry"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: "https://github.com/seerr-team/seerr"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5610, ADR-5050
# skill: nixos-context7-gate
# repo-harvest: seerr-team/seerr (https://seerr.dev) — successor of Jellyseerr/Overseerr
# nixpkgs_attr: "seerr"
# context7: https://context7.com/seerr-team/seerr, https://context7.com/websites/seerr_dev
# - query: "systemd.services serviceConfig EnvironmentFile example"
# library: /websites/nixos_manual_nixos_unstable
# snippet: "services.shiori.environmentFile = \"/path/to/env-file\" (valid)"
# svg logo: https://github.com/grapefruit89/logorepo/blob/main/seer.svg
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.seerr;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.seerr;
  port = reg.port;
  uid = reg.uid;
  gid = reg.gid;
  stateDir = reg.stateDir;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  seerrPkg =
    if cfg.package != null then cfg.package
    else if pkgs ? seerr then pkgs.seerr
    else if pkgs ? jellyseerr then pkgs.jellyseerr
    else pkgs.overseerr;
in
lib.mkIf (cfg.enable) {
  users.users.seerr = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.seerr = {
    after = [ "network.target" "jellyfin-5510.service" ];
    requires = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      # .NET profile: MemoryDenyWriteExecute=false (JIT), PrivateDevices=true
      # SystemCallErrorNumber=EPERM comes from base profile (no SIGSYS kill)
      profiles.dotnet
      {
        ExecStart = lib.getExe seerrPkg;
        User = "seerr";
        Group = "media";
        UMask = "0002";
        StateDirectory = "seerr-${toString port}";
        ReadWritePaths = [ stateDir ];
        # caddyClass=public from registry → LAN+WAN, compression (handled by 511-caddy)
      }
      (lib.mkIf (cfg.envFile or null != null) {
        EnvironmentFile = cfg.envFile;
      })
      (lib.mkIf (svc.secrets.seerrApiKeyFile or null != null) {
        LoadCredentialEncrypted = [ "seerr-api-key:${svc.secrets.seerrApiKeyFile}" ];
      })
    ];
    environment = {
      PORT = toString port;
      HOST = "127.0.0.1";
    };
  };

  medinix.ingress.vhosts."seerr" = {
    accessGroup = reg.caddyClass;
    landing = true;
    iconSvg = ''
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 96 96">
        <defs>
          <linearGradient id="a" x1="24" x2="93.5" y1="24" y2="93.5" gradientUnits="userSpaceOnUse">
            <stop offset="0" stop-color="#c395fc"/>
            <stop offset="1" stop-color="#4f65f5"/>
          </linearGradient>
          <linearGradient id="b" x1="28" x2="28" y1="8" y2="48" gradientUnits="userSpaceOnUse">
            <stop offset="0" stop-color="#fff" stop-opacity=".4"/>
            <stop offset="1" stop-color="#fff" stop-opacity="0"/>
          </linearGradient>
        </defs>
        <circle cx="48" cy="48" r="48" fill="url(#a)"/>
        <circle cx="52" cy="52" r="28" fill="#131928"/>
        <circle cx="38" cy="38" r="14" fill="url(#a)"/>
        <path fill="#131928" d="M24 52a30 30 0 1 0 28-28 28 28 0 1 1-28 28" opacity=".2"/>
        <path fill="none" stroke="url(#b)" stroke-linecap="round" stroke-width="8" d="M48 8A40 40 0 0 0 8 48"/>
      </svg>
    '';
  };


}
