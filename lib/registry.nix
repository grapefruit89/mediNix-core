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
  # caddyClass: how Caddy exposes the service (ADR-5110 final schema)
  #   stream   → WAN, Cloudflare NOT proxied, flush_interval -1, no compression
  #   internal → LAN only, DDNS → router IP, external IPs blocked
  #   public   → LAN + WAN, compression, no streaming timeouts
  #   none     → no Caddy vHost (e.g. cloudflare-dns)
  mkService = name: number: class: {
    inherit name;
    num    = number;
    port   = number * 10;        # Port = Number × 10 (ADR-5043)
    uid    = number * 10;         # UID = Port (isomorph)
    gid    = 5000;               # shared mediNix media group
    caddyClass = class;
  };
  mkNoPort = name: number: {
    inherit name;
    num    = number;
    port   = null;               # no network service
    uid    = null;
    gid    = 5000;
    caddyClass = "none";
  };
in
{
  services = {
    # Ingress (folder 51)
    caddy          = mkService "caddy" 511 "stream";
    pocket-id      = mkService "pocket-id" 512 "public";
    cloudflare-dns = mkNoPort "cloudflare-dns" 513;

    # Acquisition (*arr stack — folder 53)
    sonarr   = mkService "sonarr" 532 "internal";
    radarr   = mkService "radarr" 533 "internal";
    readarr  = mkService "readarr" 534 "internal";
    lidarr   = mkService "lidarr" 535 "internal";
    prowlarr = mkService "prowlarr" 536 "internal";

    # Transfer (folder 54)
    sabnzbd  = mkService "sabnzbd" 541 "internal";

    # Playback (folder 55)
    jellyfin       = mkService "jellyfin" 551 "stream";
    audiobookshelf = mkService "audiobookshelf" 552 "stream";
    navidrome      = mkService "navidrome" 553 "stream";
    feishin        = mkService "feishin" 554 "stream";

    # Requests (folder 56)
    jellyseerr = mkService "jellyseerr" 561 "public";

    # Observability (folder 58)
    ntfy = mkService "ntfy" 581 "public";
  };

  # For backward compat: only services with a port
  ports = lib.filterAttrs (_: v: v != null)
    (builtins.mapAttrs (_: svc: svc.port) services);
}
