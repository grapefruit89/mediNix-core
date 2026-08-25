# ---
# id: "551-jellyfin"
# title: "Jellyfin — Media Playback (55-playback, Service 551)"
# domain: 55
# folder: 55-playback
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links: 
# provides: []
# requires: ["lib/hardening-profiles"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5510, ADR-5050
# skill: nixos-context7-gate
# unraid_ref: jellyfin container --tmpfs /transcode:size=4G --group-add video
# context7: 
# - query: "systemd.services serviceConfig TemporaryFileSystem tmpfs RuntimeDirectory example"
# library: /websites/nixos_manual_nixos_unstable
# snippet: "serviceConfig.TemporaryFileSystem + SupplementaryGroups (video) valid"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.jellyfin;
  svc = config.medinix;
  port = 5510;  # 551 × 10
  uid  = 5510;
  gid  = 5000;
  stateDir   = "/var/lib/jellyfin-${toString port}";
  metadataDir = "${svc.storage.metadataDir}/jellyfin";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in
lib.mkIf (cfg.enable) {
  users.users.jellyfin = {
    uid = uid; group = "media"; extraGroups = [ "media" "video" "render" ];  # render for /dev/dri (Vector DB Finding Topic-21)
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.jellyfin = {
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      # dotnet-gpu profile: PrivateDevices=false (VA-API /dev/dri VISIBLE!), MemoryDenyWriteExecute=false (.NET JIT)
      profiles.dotnet-gpu
      {
        ExecStart = "${pkgs.jellyfin}/bin/jellyfin --datadir ${stateDir} --cachedir ${metadataDir} --webdir ${pkgs.jellyfin-web}/share/jellyfin-web";
        User = "jellyfin";
        Group = "media";
        UMask = "0002";
        SupplementaryGroups = [ "video" "render" ];  # render group for DRI access (Topic-21)
        # Explicit DeviceAllow instead of just PrivateDevices=false (Topic-21: "too restrictive otherwise")
        DeviceAllow = lib.mkIf (svc.hardware.renderDevice != null) [ "${svc.hardware.renderDevice} rwm" ];
        StateDirectory = "jellyfin-${toString port}";
        # Tier 3 (HDD media) read-only — sufficient
        ReadWritePaths = [ stateDir metadataDir ];
        BindReadOnlyPaths = [ "${svc.storage.mediaRoot}:${svc.storage.mediaRoot}" ];
        # Docker --tmpfs /transcode:size=4G → tmpfs for HW-transcode
        TemporaryFileSystem = "/transcode:size=4G";
        RuntimeDirectory = "jellyfin-transcode";
        # Admin password via systemd-creds (ADR-5510: Jellyfin stores First-Run in DB, password must be present BEFORE start)
        LoadCredentialEncrypted = lib.mkIf (cfg.adminPasswordFile != null)
          [ "jellyfin-admin-pw:${cfg.adminPasswordFile}" ];
      }
    ];
    environment = {
      JELLYFIN_PublishedServerUrl = if (svc.domain != null) then "https://jellyfin.${svc.domain}" else "http://jellyfin.local";
      # HW-transcode temp dir
      JELLYFIN_TRANSCODE_DIR = "/transcode";
      # INV-BIND-01: Explicitly bind Jellyfin to 127.0.0.1 (never 0.0.0.0)
      JELLYFIN_NetworkConfiguration__LocalNetworkAddresses = "127.0.0.1";
    } // lib.optionalAttrs (svc.hardware.accel != "none") {
      # Intel QuickSync VA-API (Topic-21: missing Env-Vars). Derive from accel, don't hardcode.
      LIBVA_DRIVER_NAME = {
        "auto"   = "iHD";
        "intel"  = "iHD";
        "vaapi"  = "iHD";
        "amd"    = "radeonsi";
        "nvidia" = null;  # NVENC uses CUDA, not VA-API
      }.${svc.hardware.accel} or null;
      VDPAU_DRIVER = "va_gl";
    } // lib.optionalAttrs (cfg.adminPasswordFile != null) {
      # Jellyfin reads Admin password from Env on First-Run
      JELLYFIN_ADMIN_PASSWORD__FILE = "/run/credentials/jellyfin/jellyfin-admin-pw";
    };
  };

  medinix.ingress.vhosts."jellyfin" = { accessGroup = reg.caddyClass; };

  systemd.services."jellyfin" = lib.mkIf (cfg.secrets.jellyfinAdminPasswordFile != null) {
    serviceConfig.LoadCredentialEncrypted = [ "jellyfin-api-key:${cfg.secrets.jellyfinAdminPasswordFile}" ];
  };

  # Hardware Acceleration (VA-API / QuickSync) Dependencies
  hardware.graphics = lib.mkIf (svc.hardware.accel == "intel" || svc.hardware.accel == "vaapi") {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # iHD driver
      vpl-gpu-rt        # QSV on 11th gen+
      intel-vaapi-driver # i965 (older GPUs)
      intel-compute-runtime # OpenCL filter support
    ];
  };
}
