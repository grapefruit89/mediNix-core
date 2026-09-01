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
  # profile: systemd-hardening profile from lib/hardening-profiles.nix
  #   (base | dotnet | dotnet-gpu | python | nodejs | network | script)
  mkService = name: number: profile: caddyClass: {
    inherit name;
    unitName = name;
    num    = number;
    port   = number * 10;        # Port = Number × 10 (ADR-5043)
    uid    = number * 10;         # UID = Port (isomorph)
    gid    = 5000;               # shared mediNix media group
    stateDir = "/var/lib/${name}-${toString (number * 10)}";
    hardeningProfile = profile;
    caddyClass = caddyClass;
  };
  mkNoPort = name: number: profile: caddyClass: {
    inherit name;
    unitName = name;
    num    = number;
    port   = null;               # no network service
    uid    = null;
    gid    = 5000;
    stateDir = null;
    hardeningProfile = profile;
    caddyClass = caddyClass;
  };
in
rec {
  services = {
    # Ingress (folder 51)
    caddy          = mkService "caddy" 511 "network" "none";
    pocket-id      = mkService "pocket-id" 512 "network" "public";
    cloudflare-dns = mkNoPort "cloudflare-dns" 513 "script" "none";

    # Acquisition (*arr stack — folder 53) — all .NET
    sonarr   = mkService "sonarr" 532 "dotnet" "internal";
    radarr   = mkService "radarr" 533 "dotnet" "internal";
    readarr  = mkService "readarr" 534 "dotnet" "internal";
    lidarr   = mkService "lidarr" 535 "dotnet" "internal";
    prowlarr = mkService "prowlarr" 536 "dotnet" "internal";

    # Transfer (folder 54) — Python
    sabnzbd  = mkService "sabnzbd" 541 "python" "internal";

    # Playback (folder 55) — Jellyfin GPU, rest nodejs/network
    jellyfin       = mkService "jellyfin" 551 "dotnet-gpu" "stream";
    audiobookshelf = mkService "audiobookshelf" 552 "nodejs" "stream";
    navidrome      = mkService "navidrome" 553 "nodejs" "stream";
    feishin        = mkNoPort "feishin" 554 "network" "none";
    seerr     = mkService "seerr" 555 "dotnet" "public";

    # Requests (folder 56) — currently empty / reserved

    # Observability (folder 58) — Go binary, network port-binding
    ntfy = mkService "ntfy" 581 "network" "none";
    # CrowdSec native agent (folder 58) — no port (Caddy plugin talks to localhost)
    crowdsec = mkNoPort "crowdsec" 582 "script" "none";
  };

  # For backward compat: only services with a port
  ports = lib.filterAttrs (_: v: v != null)
    (builtins.mapAttrs (_: svc: svc.port) services);
}
