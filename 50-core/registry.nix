# ---
# id: "registry"
# title: "mediNix SSoT Registry"
# domain: 50
# folder: 50-core
# last_reviewed: 2026-09-02
# status: active
# kind: library
# complexity: 1
# links:
#   adr: ADR-0000
# ---
{ lib, ... }:

let
  # EINE Ableitungs-Formel (50-core/derive.nix) — nicht doppelt pflegen (DRY/SSOT).
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
  mkUdsService =
    name: number: profile: caddyClass: unitName:
    (mkServiceWithUnit name number profile caddyClass unitName)
    // {
      uds_socket = true;
      uds_path = "/run/${name}/${name}.sock";
      # port NICHT überschreiben — bleibt number * 10
    };
in
rec {
  services = {
    caddy = mkService "caddy" 511 "network" "none";
    pocket-id = mkUdsService "pocket-id" 512 "network" "public" "pocket-id";
    # L1a: "network", nicht "script". `script` setzt PrivateNetwork = true und
    # RestrictAddressFamilies = [ "AF_UNIX" ] — ein DDNS-Client ohne Netz ist
    # nutzlos. Das Modul uebergibt "network"; die Registry war falsch.
    cloudflare-dns = mkNoPortWithUnit "cloudflare-dns" 513 "network" "none" "cloudflare-ddns";
    # Die Zweit-Unit `cloudflare-ddns-reconnect` (513-ddns.nix) steht bewusst
    # NICHT in dieser Registry: sie hat keinen eigenen Account, keinen Port und
    # teilt uid/stateDir mit cloudflare-dns. Sie uebergibt ihr Profil explizit.
    blocky = mkNoPortWithUnit "blocky" 515 "network" "none" "blocky";
    crowdsec = mkNoPortWithUnit "crowdsec" 516 "network" "none" "crowdsec";
    # L1b-Folge: 517 handbaut seine serviceConfig (517-oauth2-proxy.nix) und
    # nutzt das Profil noch nicht. Der Wert hier ist der SOLL-Zustand.
    oauth2-proxy = mkUdsService "oauth2-proxy" 517 "network" "none" "oauth2-proxy";

    sonarr = mkService "sonarr" 532 "dotnet" "internal";
    radarr = mkService "radarr" 533 "dotnet" "internal";
    readarr = mkService "readarr" 534 "dotnet" "internal";
    lidarr = mkService "lidarr" 535 "dotnet" "internal";
    prowlarr = mkService "prowlarr" 536 "dotnet" "internal";

    sabnzbd = mkService "sabnzbd" 541 "python" "internal";

    jellyfin = mkService "jellyfin" 551 "dotnet-gpu" "stream";
    audiobookshelf = mkService "audiobookshelf" 552 "nodejs" "stream";
    navidrome = mkUdsService "navidrome" 553 "nodejs" "stream" "navidrome";
    seerr = mkService "seerr" 561 "nodejs" "public";

    # L1a: "base", nicht "network". 582 uebergibt "base" bewusst (der Dienst
    # pollt HTTP-Endpunkte; `network` braechte IPAddressDeny/SocketBind* und
    # PrivateDevices — ungeprueft). Die Registry war der SOLL-Wert, das Modul
    # der Ist-Zustand; jetzt steht beides gleich.
    gatus = mkService "gatus" 582 "base" "internal";

    # caddyClass "internal" (RT-5/Doc-Konsistenz): 581 veröffentlicht den
    # ntfy-vHost als internal (Assertion verbietet public/stream) — die
    # Registry dokumentiert dasselbe, statt "none" zu behaupten.
    ntfy = mkUdsService "ntfy" 581 "network" "internal" "ntfy";
  };

  ports = lib.filterAttrs (_: v: v != null) (builtins.mapAttrs (_: svc: svc.port) services);
}
