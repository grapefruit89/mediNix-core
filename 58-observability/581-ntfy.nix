# ---
# id: "581-ntfy"
# title: "ntfy.sh — Push Notifications for Arr-Stack + Jellyfin (58-observability, Service 581)"
# domain: 58
# folder: 58-observability
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5810, ADR-5050
#   skill: nixos-context7-gate
#   repo-harvest: ntfy.sh (Go binary, native arr/Jellyfin support)
# context7:
#   - query: "services.ntfy-sh enable configuration port example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "services.ntfy-sh.enable + settings (freeform submodule pattern)"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.observability.ntfy;
  svc = config.grapefruitMedia;
  port = 5810;  # 581 × 10
  uid  = 5810;
  gid  = 5000;
  stateDir = "/var/lib/ntfy-sh-${toString port}";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in lib.mkIf cfg.enable {
  users.users.ntfy = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = cfg.baseUrl;
      listen-http = "127.0.0.1:${toString port}";  # bind loopback, Caddy exposes
      cache-file = "${stateDir}/cache.db";
      attachment-cache-dir = "${stateDir}/attachments";
    };
  };

  systemd.services.ntfy-sh.serviceConfig = lib.mkMerge [ profiles.network { User = "ntfy"; Group = "media"; } ];

  # caddyClass=public → LAN+WAN reachable (notifications from mobile)
  # 511-caddy.nix picks this up from registry (ntfy.caddyClass="public")

  grapefruitMedia.ingress.vhosts."ntfy" = { accessGroup = "public"; };

  grapefruitMedia.ingress.vhosts."ntfy" = { accessGroup = "public"; };
}

