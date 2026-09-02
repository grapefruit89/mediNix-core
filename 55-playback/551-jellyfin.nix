# ---
# id: "551-jellyfin"
# title: "Jellyfin — Media Playback"
# domain: 55
# last_reviewed: 2026-09-02
# sprite: 50-core/icons.svg#jellyfin
# adr: ADR-551
# ---
# WAN stream + app login. 518 tiles this because accessGroup = stream.
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.jellyfin;
  svc = config.medinix;
  creds = import ../lib/creds.nix { inherit lib; };
  port = 5510;
  uid = 5510;
  gid = 5000;
  stateDir = "/var/lib/jellyfin-${toString port}";
  metadataDir = "${svc.storage.metadataDir}/jellyfin";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  adminCred =
    if cfg.adminPasswordFile != null then cfg.adminPasswordFile
    else if cfg.adminPasswordCredential != null then cfg.adminPasswordCredential
    else null;
in
lib.mkIf cfg.enable {
  assertions = [
    {
      assertion = adminCred != null;
      message = ''
        [mediNix] jellyfin is on the WAN stream vhost. Set
        medinix.jellyfin.adminPasswordCredential (or adminPasswordFile)
        to a systemd-creds blob. No default admin. No Pocket-ID SSO.
      '';
    }
  ];

  users.users.jellyfin = {
    uid = uid;
    group = "media";
    extraGroups = [ "video" "render" ];
    home = stateDir;
    isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.jellyfin = {
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      profiles.dotnet-gpu
      {
        ExecStart = "${pkgs.jellyfin}/bin/jellyfin --datadir ${stateDir} --cachedir ${metadataDir} --webdir ${pkgs.jellyfin-web}/share/jellyfin-web";
        User = "jellyfin";
        Group = "media";
        UMask = "0002";
        SupplementaryGroups = [ "video" "render" ];
        DeviceAllow = lib.mkIf (svc.hardware.renderDevice != null) [ "${svc.hardware.renderDevice} rwm" ];
        StateDirectory = "jellyfin-${toString port}";
        ReadWritePaths = [ stateDir metadataDir ];
        BindReadOnlyPaths = [ "${svc.storage.mediaRoot}:${svc.storage.mediaRoot}" ];
        InaccessiblePaths = [ creds.storeDir ];
        TemporaryFileSystem = "/transcode:size=4G";
        RuntimeDirectory = "jellyfin-transcode";
        LoadCredentialEncrypted = lib.mkIf (adminCred != null) [
          "jellyfin-admin-pw:${adminCred}"
        ];
      }
    ];
    environment = {
      JELLYFIN_PublishedServerUrl =
        if svc.domain != null then "https://jellyfin.${svc.domain}" else "http://jellyfin.local";
      JELLYFIN_TRANSCODE_DIR = "/transcode";
    } // lib.optionalAttrs (svc.hardware.accel != "none") {
      LIBVA_DRIVER_NAME = {
        "auto" = "iHD";
        "intel" = "iHD";
        "vaapi" = "iHD";
        "amd" = "radeonsi";
        "nvidia" = null;
      }.${svc.hardware.accel} or null;
      VDPAU_DRIVER = "va_gl";
    } // lib.optionalAttrs (adminCred != null) {
      JELLYFIN_ADMIN_PASSWORD__FILE = "/run/credentials/jellyfin.service/jellyfin-admin-pw";
    };
  };

  medinix.ingress.vhosts."jellyfin" = { accessGroup = "stream"; };

  hardware.graphics = lib.mkIf (svc.hardware.accel == "intel" || svc.hardware.accel == "vaapi") {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
      intel-vaapi-driver
      intel-compute-runtime
    ];
  };
}
