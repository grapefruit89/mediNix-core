# ---
# id: "554-feishin"
# title: "Feishin — static SPA for Navidrome/Jellyfin (55-playback, Service 554)"
# domain: 55
# folder: 55-playback
# status: active
# complexity: 2
# last_reviewed: 2026-08-11
# links: 
# provides: []
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5530
# skill: nixos-context7-gate
# gold: CLAUDE.md (no process; static files; try_files mandatory; not a replacement)
# context7: 
# - query: "services.caddy virtualHosts extraConfig file_server try_files example"
# library: /websites/nixos_manual_nixos_unstable
# snippet: "extraConfig file_server + try_files {path} /index.html for SPA"
# svg logo: https://github.com/grapefruit89/logorepo/blob/main/feishin.svg
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.feishin;
  svc = config.medinix;
  # No process — pure static SPA. Number 554 exists for registry completeness.
  # Port 5540 is never bound; Caddy serves the SPA.
in lib.mkIf (cfg.enable) {
  # Feishin SPA served via Caddy (caddyClass=stream from registry → auto vHost).
  # We inject the file_server block through the Caddyfile extraConfig.
  # The 511-caddy.nix stream template already adds flush_interval -1; here we
  # force a static file_server with SPA try_files.
  # NOTE: This is layered on top of the stream template via a dedicated vHost.
  environment.etc."caddy-media/feishin-include" = lib.mkIf (!config.services.caddy.enable) {
    text = ''
      root * ${pkgs.feishin-web}/share/feishin-web
      try_files {path} /index.html
      file_server
    '';
  };

  # If global Caddy is used, inject via virtualHosts extraConfig
  services.caddy.virtualHosts = lib.mkIf config.services.caddy.enable {
    "${if svc.domain != null then "feishin.${svc.domain}" else "feishin.local"}" = {
      extraConfig = ''
        root * ${pkgs.feishin-web}/share/feishin-web
        try_files {path} /index.html
        file_server
      '';
    };
  };

  medinix.ingress.vhosts."feishin" = {
    accessGroup = "none";
    landing = true;
    iconSvg = ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
        <rect width="512" height="512" rx="96" fill="#111827"/>
        <path fill="#38bdf8" d="M160 120h48v176c0 48 40 88 88 88s88-40 88-88-40-88-88-88c-10 0-20 2-28 5V120H160zm136 228c-26 0-48-22-48-48s22-48 48-48 48 22 48 48-22 48-48 48z"/>
      </svg>
    '';
  };

  # Assertion: Feishin needs a backend (Navidrome/Jellyfin) — CLAUDE.md gold
  assertions = [ {
    assertion = svc.navidrome.enable || svc.jellyfin.enable || (cfg.serverUrl or null != null);
    message = "554-feishin: needs Navidrome, Jellyfin, or explicit serverUrl — SPA has no backend otherwise.";
  } ];
}
