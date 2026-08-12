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
  # profile: systemd-hardening profile from lib/hardening-profiles.nix
  #   (base | dotnet | dotnet-gpu | python | nodejs | network | script)
  mkService = name: number: class: profile: {
    inherit name;
    num    = number;
    port   = number * 10;        # Port = Number × 10 (ADR-5043)
    uid    = number * 10;         # UID = Port (isomorph)
    gid    = 5000;               # shared mediNix media group
    caddyClass = class;
    hardeningProfile = profile;
  };
  mkNoPort = name: number: profile: {
    inherit name;
    num    = number;
    port   = null;               # no network service
    uid    = null;
    gid    = 5000;
    caddyClass = "none";
    hardeningProfile = profile;
  };
in
{
  services = {
    # Ingress (folder 51)
    caddy          = mkService "caddy" 511 "stream" "network";
    pocket-id      = mkService "pocket-id" 512 "public" "network";
    cloudflare-dns = mkNoPort "cloudflare-dns" 513 "script";

    # Acquisition (*arr stack — folder 53) — all .NET
    sonarr   = mkService "sonarr" 532 "internal" "dotnet";
    radarr   = mkService "radarr" 533 "internal" "dotnet";
    readarr  = mkService "readarr" 534 "internal" "dotnet";
    lidarr   = mkService "lidarr" 535 "internal" "dotnet";
    prowlarr = mkService "prowlarr" 536 "internal" "dotnet";

    # Transfer (folder 54) — Python
    sabnzbd  = mkService "sabnzbd" 541 "internal" "python";

    # Playback (folder 55) — Jellyfin GPU, rest nodejs/network
    jellyfin       = mkService "jellyfin" 551 "stream" "dotnet-gpu";
    audiobookshelf = mkService "audiobookshelf" 552 "stream" "nodejs";
    navidrome      = mkService "navidrome" 553 "stream" "nodejs";
    feishin        = mkNoPort "feishin" 554 "network";

    # Requests (folder 56) — .NET + Python (Bazarr)
    jellyseerr = mkService "jellyseerr" 561 "public" "dotnet";
    bazarr     = mkService "bazarr"     562 "internal" "python";

    # Observability (folder 58) — Go binary, network port-binding
    ntfy = mkService "ntfy" 581 "public" "network";
    # CrowdSec native agent (folder 58) — no port (Caddy plugin talks to localhost)
    crowdsec = mkNoPort "crowdsec" 582 "none";
  };

  # For backward compat: only services with a port
  ports = lib.filterAttrs (_: v: v != null)
    (builtins.mapAttrs (_: svc: svc.port) services);
}
