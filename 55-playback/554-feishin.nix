# ---
# id: "554-feishin"
# title: "Feishin — static SPA"
# domain: 55
# last_reviewed: 2026-10-13
# sprite: 50-core/icons.svg#feishin
# adr: ADR-554
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.feishin;
  svc = config.medinix;
in
{
  config = lib.mkMerge [
    {
      medinix.manifest.feishin = {
        inherit (cfg) enable;
        hasDaemon = false;
        num = 554;
        accessGroup = "public";
        customConfig = ''
          root * ${pkgs.feishin-web}/share/feishin-web
          try_files {path} /index.html
          file_server
        '';
        ui = {
          title = "Feishin";
          description = "Musik-Streaming Web-Player";
          icon = "feishin";
          group = "Media";
          showOnLanding = true;
        };
        monitoring = {
          enable = false;
          type = "none";
        };
        ops = {
          priority = "low";
          ramBudget = "0M";
          notes = "Statische Single-Page-App (file_server), kein Daemon.";
        };
        sources = {
          upstream = "https://github.com/jeffvli/feishin";
          repo = "https://github.com/jeffvli/feishin";
          nixos = "https://search.nixos.org/packages?query=feishin-web";
        };
      };
    }

    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = svc.navidrome.enable || svc.jellyfin.enable || ((cfg.serverUrl or null) != null);
          message = "554-feishin needs Navidrome, Jellyfin, or serverUrl.";
        }
      ];
    })
  ];
}
