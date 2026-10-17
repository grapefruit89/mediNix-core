# ---
# id: "registry"
# title: "mediNix SSoT Registry"
# domain: 50
# last_reviewed: 2026-09-02
# ---
{ lib, ... }:

let
  # EINE Ableitungs-Formel (lib/derive.nix) — nicht doppelt pflegen (DRY/SSOT).
  df = import ./derive.nix;

  mkServiceWithUnit = name: number: profile: caddyClass: unitName: {
    inherit name;
    unitName = if unitName != null then unitName else name;
    inherit (df.derive name number)
      num
      port
      uid
      sharedGid
      stateDir
      ;
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
    # Unit ohne eigenen Listener: Account existiert (z. B. 513 -> 5130), aber keine Bindung
    uid = if unitName != null then number * 10 else null;
    inherit (df.derive name number) sharedGid;
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
    crowdsec = mkNoPortWithUnit "crowdsec" 516 "network" "none" "crowdsec";
    oauth2-proxy = mkService "oauth2-proxy" 517 "network" "none";

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

    gatus = mkService "gatus" 582 "network" "internal";

    # caddyClass "internal" (RT-5/Doc-Konsistenz): 581 veröffentlicht den
    # ntfy-vHost als internal (Assertion verbietet public/stream) — die
    # Registry dokumentiert dasselbe, statt "none" zu behaupten.
    ntfy = mkService "ntfy" 581 "network" "internal";
  };

  ports = lib.filterAttrs (_: v: v != null) (builtins.mapAttrs (_: svc: svc.port) services);
}
