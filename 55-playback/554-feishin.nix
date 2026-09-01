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
# No daemon. 511 serves the files because customConfig is set and the
# registry port is null. Do not write services.caddy.* here.
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
    customConfig = ''
      root * ${pkgs.feishin-web}/share/feishin-web
      encode off
      try_files {path} /index.html
      file_server
    '';
    iconSvg = ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
        <rect width="512" height="512" rx="96" fill="#111827"/>
        <path fill="#38bdf8" d="M160 120h48v176c0 48 40 88 88 88s88-40 88-88-40-88-88-88c-10 0-20 2-28 5V120H160zm136 228c-26 0-48-22-48-48s22-48 48-48 48 22 48 48-22 48-48 48z"/>
      </svg>
    '';
  };
}
