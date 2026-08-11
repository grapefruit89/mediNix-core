# ---
# id: "registry"
# title: "mediNix SSoT Registry (ports/uid/gid, isomorph)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5043
# provides: ["ports", "uids", "services"]
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---

# lib/registry.nix — Single Source of Truth (SSoT)
# Isomorphie: UID = Port = Number × 10 (Number = folder digit)
# ADR-5043: mediNix decimal framework. Port ends always in 0.
# cloudflare-dns (513) has no port/uid (no network service).
{ lib, ... }:

let
  mkService = name: number: {
    inherit name;
    num    = number;
    port   = number * 10;        # Port = Number × 10 (ADR-5043)
    uid    = number * 10;         # UID = Port (isomorph)
    gid    = 5000;               # shared mediNix media group
    wan    = false;
    stream = false;
  };
  mkNoPort = name: number: {
    inherit name;
    num    = number;
    port   = null;               # no network service
    uid    = null;
    gid    = 5000;
  };
in
{
  services = {
    # Ingress (folder 51)
    caddy          = mkService "caddy" 511;
    pocket-id      = mkService "pocket-id" 512;
    cloudflare-dns = mkNoPort "cloudflare-dns" 513;

    # Acquisition (*arr stack — folder 53)
    sonarr   = mkService "sonarr" 532;
    radarr   = mkService "radarr" 533;
    readarr  = mkService "readarr" 534;
    lidarr   = mkService "lidarr" 535;
    prowlarr = mkService "prowlarr" 536;

    # Transfer (folder 54)
    sabnzbd  = mkService "sabnzbd" 541 // { stream = true; };

    # Playback (folder 55)
    jellyfin       = mkService "jellyfin" 551 // { stream = true; wan = true; };
    audiobookshelf = mkService "audiobookshelf" 552;
    navidrome      = mkService "navidrome" 553;
    feishin        = mkService "feishin" 554;

    # Requests (folder 56)
    jellyseerr = mkService "jellyseerr" 561;
  };

  # For backward compat: only services with a port
  ports = lib.filterAttrs (_: v: v != null)
    (builtins.mapAttrs (_: svc: svc.port) services);
}
