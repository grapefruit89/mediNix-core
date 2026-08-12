# ---
# id: "562-bazarr"
# title: "Bazarr — Subtitle Downloader for Sonarr/Radarr (56-requests, Dienst 562)"
# domain: 56
# folder: 56-requests
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5620
#   skill: nixos-context7-gate
#   repo-harvest: bazarr/bazarr (native services.bazarr, python)
# context7:
#   - query: "services.bazarr enable port user group settings"
#     library: /nixos/nixpkgs
#     snippet: "services.bazarr.enable + settings"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.bazarr;
  svc = config.grapefruitMedia;
  port = 5620;  # 562 × 10
  uid  = 5620;
  gid  = 5000;
  stateDir = "/var/lib/bazarr-${toString port}";
in
{
  config = lib.mkIf cfg.enable {
    users.users.bazarr = {
      uid = uid; group = "media"; extraGroups = [ "media" ];
      home = stateDir; isSystemUser = true;
    };
    users.groups.media.gid = gid;

    services.bazarr = {
      enable      = true;
      openFirewall = false;
      port        = port;
      user        = "bazarr";
      group       = "media";
      dataDir     = stateDir;
      settings = {
        general = {
          host = "127.0.0.1";
          port = port;
          # Sonarr/Radarr-URLs via Caddy-Internal-Hostname
          sonarr = {
            base_url  = "http://127.0.0.1:5320";
            api_key   = svc.secrets.sonarrApiKeyFile;
          };
          radarr = {
            base_url  = "http://127.0.0.1:5330";
            api_key   = svc.secrets.radarrApiKeyFile;
          };
        };
      };
    };

    # Bazarr State-Dir + Permissions
    systemd.services.bazarr = {
      serviceConfig = lib.mkMerge [
        (import ../lib/hardening-profiles.nix { inherit lib; }).python
        {
          User            = "bazarr";
          Group           = "media";
          UMask           = "0002";
          StateDirectory  = "bazarr-${toString port}";
          ReadWritePaths  = [ stateDir ];
        }
      ];
    };
  };
}
