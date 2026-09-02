# ---
# id: "554-feishin"
# title: "Feishin — static SPA (no process, no port)"
# domain: 55
# folder: 55-playback
# status: active
# last_reviewed: 2026-09-02
# provides: ["feishin"]
# requires: ["511-caddy"]
# adr: ADR-554
# ---
# No daemon. Logo: logos/feishin.svg → 518 #feishin.
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
    accessGroup = "stream";
    landing = true;
    iconId = "feishin";
    customConfig = ''
      root * ${pkgs.feishin-web}/share/feishin-web
      encode off
      try_files {path} /index.html
      file_server
    '';
  };
}
