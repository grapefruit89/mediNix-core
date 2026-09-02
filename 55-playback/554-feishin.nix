# ---
# id: "554-feishin"
# title: "Feishin — static SPA"
# domain: 55
# last_reviewed: 2026-09-02
# sprite: 50-core/icons.svg#feishin
# adr: ADR-554
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.feishin;
  svc = config.medinix;
in
lib.mkIf cfg.enable {
  assertions = [ {
    assertion = svc.navidrome.enable || svc.jellyfin.enable || (cfg.serverUrl or null != null);
    message = "554-feishin needs Navidrome, Jellyfin, or serverUrl.";
  } ];

  medinix.ingress.vhosts."feishin" = {
    accessGroup = "public";
    customConfig = ''
      root * ${pkgs.feishin-web}/share/feishin-web
      encode off
      try_files {path} /index.html
      file_server
    '';
  };
}
