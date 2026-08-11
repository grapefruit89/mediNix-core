# ---
# id: "registry"
# title: "mediNix SSoT Registry (ports/uid/gid, isomorph)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 4
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-5043
# provides: ["ports", "uids", "wan_flags"]
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: "https://github.com/grapefruit89/mediNix"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---

# lib/registry.nix — Single Source of Truth (SSoT)
# Isomorphie: UID = Port = Number × 10 (Number = folder digit)
# ADR-5043: mediNix decimal frame. Port ends always in 0.
{ lib, ... }:

let
  mkService = name: number: {
    inherit name;
    port = number * 10;        # Port = Number × 10 (ADR-5043)
    uid = number * 10;         # UID = Port (isomorph)
    number = number;
    gid = 5000;                # shared mediNix media group
    wan = false;
    stream = false;
  };
in
{
  # Ingress
  caddy = mkService "caddy" 511;

  # Acquisition (*arr stack) — folder 53
  prowlarr = mkService "prowlarr" 531;
  sonarr   = mkService "sonarr" 532;
  radarr   = mkService "radarr" 533;
  lidarr   = mkService "lidarr" 534;
  readarr  = mkService "readarr" 535;

  # Transfer (folder 54)
  sabnzbd  = mkService "sabnzbd" 541 // { stream = true; wan = false; };

  # Playback (folder 55)
  jellyfin       = mkService "jellyfin" 551 // { stream = true; wan = true; };
  audiobookshelf = mkService "audiobookshelf" 552;
  navidrome      = mkService "navidrome" 553;

  # Requests (folder 56)
  jellyseerr = mkService "jellyseerr" 561;
}
