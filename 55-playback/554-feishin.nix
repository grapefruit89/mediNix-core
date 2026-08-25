# ---
# id: "554-feishin"
# title: "Feishin — static SPA for Navidrome/Jellyfin (55-playback, Service 554)"
# domain: 55
# folder: 55-playback
# status: active
# complexity: 2
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5530
#   skill: nixos-context7-gate
#   gold: CLAUDE.md (no process; static files; try_files mandatory; not a replacement)
# context7:
#   - query: "services.caddy virtualHosts extraConfig file_server try_files example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "extraConfig file_server + try_files {path} /index.html for SPA"
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

  # Assertion: Feishin needs a backend (Navidrome/Jellyfin) — CLAUDE.md gold
  assertions = [ {
    assertion = svc.navidrome.enable || svc.jellyfin.enable || (cfg.serverUrl or null != null);
    message = "554-feishin: needs Navidrome, Jellyfin, or explicit serverUrl — SPA has no backend otherwise.";
  } ];
}
