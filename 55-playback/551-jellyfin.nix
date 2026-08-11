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
    uid = uid; group = "media"; extraGroups = [ "media" "video" ];
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
        SupplementaryGroups = [ "video" ];
        StateDirectory = "jellyfin-${toString port}";
        # Tier 3 (HDD media) read-only — reicht
        ReadWritePaths = [ stateDir metadataDir ];
        BindReadOnlyPaths = [ "${svc.storage.mediaRoot}:${svc.storage.mediaRoot}" ];
        # Docker --tmpfs /transcode:size=4G → tmpfs for HW-transcode
        TemporaryFileSystem = "/transcode:size=4G";
        RuntimeDirectory = "jellyfin-transcode";
      }
    ];
    environment = {
      JELLYFIN_PublishedServerUrl = "https://jellyfin.${svc.domain}";
      # HW-transcode temp dir
      JELLYFIN_TRANSCODE_DIR = "/transcode";
    };
  };
}
