# ---
# id: "registry"
# title: "mediNix SSoT Registry"
# domain: 50
# last_reviewed: 2026-09-02
# ---
{ lib, ... }:

let
  mkServiceWithUnit = name: number: profile: caddyClass: unitName: {
    inherit name;
    unitName = if unitName != null then unitName else name;
    num = number;
    port = number * 10;
    uid = number * 10;
    gid = 5000;
    stateDir = "/var/lib/${name}-${toString (number * 10)}";
    hardeningProfile = profile;
    inherit caddyClass;
  };
  mkService =
    name: number: profile: caddyClass:
    mkServiceWithUnit name number profile caddyClass name;

  mkNoPortWithUnit = name: number: profile: caddyClass: unitName: {
    inherit name;
    inherit unitName;
    num = number;
    port = null;
    uid = null;
    gid = 5000;
    stateDir = null;
    hardeningProfile = profile;
    inherit caddyClass;
  };
  mkNoPort =
    name: number: profile: caddyClass:
    mkNoPortWithUnit name number profile caddyClass null;
in
rec {
  services = {
    caddy = mkService "caddy" 511 "network" "none";
    pocket-id = mkService "pocket-id" 512 "network" "public";
    cloudflare-dns = mkNoPortWithUnit "cloudflare-dns" 513 "script" "none" "cloudflare-ddns";

    sonarr = mkService "sonarr" 532 "dotnet" "internal";
    radarr = mkService "radarr" 533 "dotnet" "internal";
    readarr = mkService "readarr" 534 "dotnet" "internal";
    lidarr = mkService "lidarr" 535 "dotnet" "internal";
    prowlarr = mkService "prowlarr" 536 "dotnet" "internal";

    sabnzbd = mkService "sabnzbd" 541 "python" "internal";

    jellyfin = mkService "jellyfin" 551 "dotnet-gpu" "stream";
    audiobookshelf = mkService "audiobookshelf" 552 "nodejs" "stream";
    navidrome = mkService "navidrome" 553 "nodejs" "stream";
    feishin = mkNoPort "feishin" 554 "network" "none";
    seerr = mkService "seerr" 561 "nodejs" "public";

    ntfy = mkServiceWithUnit "ntfy" 581 "network" "none" "ntfy-sh";
  };

  ports = lib.filterAttrs (_: v: v != null) (builtins.mapAttrs (_: svc: svc.port) services);
}
