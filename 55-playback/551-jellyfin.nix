# ---
# id: "551-jellyfin"
# title: "Jellyfin — Media Playback (55-playback, Dienst 551)"
# domain: 55
# folder: 55-playback
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5510, ADR-5050
#   skill: nixos-context7-gate
#   unraid_ref: jellyfin container --tmpfs /transcode:size=4G --group-add video
# context7:
#   - query: "systemd.services serviceConfig TemporaryFileSystem tmpfs RuntimeDirectory example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "serviceConfig.TemporaryFileSystem + SupplementaryGroups (video) valid"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.jellyfin;
  svc = config.grapefruitMedia;
  port = 5510;  # 551 × 10
  uid  = 5510;
  gid  = 5000;
  stateDir   = "/var/lib/jellyfin-${toString port}";
  metadataDir = "${svc.storage.metadataDir}/jellyfin";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in
{
  users.users.jellyfin = {
    uid = uid; group = "media"; extraGroups = [ "media" "video" "render" ];  # render für /dev/dri (Vektor-DB Finding Topic-21)
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.jellyfin = {
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      # dotnet-gpu-Profil: PrivateDevices=false (VA-API /dev/dri SICHTBAR!), MemoryDenyWriteExecute=false (.NET JIT)
      profiles.dotnet-gpu
      {
        ExecStart = "${pkgs.jellyfin}/bin/jellyfin --datadir ${stateDir} --cachedir ${metadataDir} --webdir ${pkgs.jellyfin-web}/share/jellyfin-web";
        User = "jellyfin";
        Group = "media";
        UMask = "002";
        SupplementaryGroups = [ "video" "render" ];  # render-Gruppe für DRI-Zugriff (Topic-21)
        # Explizites DeviceAllow statt nur PrivateDevices=false (Topic-21: "zu restriktiv sonst")
        DeviceAllow = lib.mkIf (svc.hardware.renderDevice != null) [ "${svc.hardware.renderDevice} rwm" ];
        StateDirectory = "jellyfin-${toString port}";
        # Tier 3 (HDD media) read-only — reicht
        ReadWritePaths = [ stateDir metadataDir ];
        BindReadOnlyPaths = [ "${svc.storage.mediaRoot}:${svc.storage.mediaRoot}" ];
        # Docker --tmpfs /transcode:size=4G → tmpfs for HW-transcode
        TemporaryFileSystem = "/transcode:size=4G";
        RuntimeDirectory = "jellyfin-transcode";
        # Admin-Passwort via systemd-creds (ADR-5510: Jellyfin speichert First-Run in DB, Passwort VOR Start da sein)
        LoadCredentialEncrypted = lib.mkIf (cfg.adminPasswordFile != null)
          [ "jellyfin-admin-pw:${cfg.adminPasswordFile}" ];
      }
    ];
    environment = {
      JELLYFIN_PublishedServerUrl = "https://jellyfin.${svc.domain}";
      # HW-transcode temp dir
      JELLYFIN_TRANSCODE_DIR = "/transcode";
      # INV-BIND-01: Jellyfin explizit auf 127.0.0.1 binden (nie 0.0.0.0)
      JELLYFIN_NetworkConfiguration__LocalNetworkAddresses = "127.0.0.1";
    } // lib.optionalAttrs (svc.hardware.accel != "none") {
      # Intel QuickSync VA-API (Topic-21: fehlende Env-Vars). Aus accel ableiten, nicht hardcoden.
      LIBVA_DRIVER_NAME = {
        "auto"   = "iHD";
        "intel"  = "iHD";
        "vaapi"  = "iHD";
        "amd"    = "radeonsi";
        "nvidia" = null;  # NVENC nutzt CUDA, kein VA-API
      }.${svc.hardware.accel} or null;
      VDPAU_DRIVER = "va_gl";
    } // lib.mkIf (cfg.adminPasswordFile != null) {
      # Jellyfin liest Admin-Passwort aus Env beim First-Run
      JELLYFIN_ADMIN_PASSWORD__FILE = "/run/credentials/jellyfin-admin-pw/jellyfin-admin-pw";
    };
  };
}
