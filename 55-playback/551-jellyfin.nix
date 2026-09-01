# ---
# id: "551-jellyfin"
# title: "Jellyfin — Media Playback (55-playback, Service 551)"
# domain: 55
# folder: 55-playback
# status: active
# complexity: 4
# last_reviewed: 2026-09-02
# links: https://jellyfin.org/
# provides: ["jellyfin"]
# requires: ["lib/hardening-profiles"]
# ports: [5510]
# upstream_docs: [https://jellyfin.org/docs/]
# forum_links: []
# upstream_github: "https://github.com/jellyfin/jellyfin"
# nixpkgs_attr: ""
# state_dir: "/var/lib/jellyfin-5510"
# uds_socket: false
# systemd_hardened: true
# adr: ADR-551
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.jellyfin;
  svc = config.medinix;
  port = 5510;
  uid = 5510;
  gid = 5000;
  stateDir = "/var/lib/jellyfin-${toString port}";
  metadataDir = "${svc.storage.metadataDir}/jellyfin";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  adminCred =
    if cfg.adminPasswordFile != null then cfg.adminPasswordFile
    else if cfg.adminPasswordCredential != null then cfg.adminPasswordCredential
    else if svc.secrets.jellyfinAdminPasswordFile != "" then svc.secrets.jellyfinAdminPasswordFile
    else null;
in
lib.mkIf cfg.enable {
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
      JELLYFIN_NetworkConfiguration__LocalNetworkAddresses = "127.0.0.1";
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

  medinix.ingress.vhosts."jellyfin" = {
    accessGroup = "stream";
    landing = true;
    iconSvg = ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 82 82">
        <linearGradient id="a" x1="17" x2="77" y1="33" y2="66" gradientUnits="userSpaceOnUse">
          <stop stop-color="#aa5cc3"/>
          <stop offset="1" stop-color="#00a4dc"/>
        </linearGradient>
        <path fill="url(#a)" fill-rule="evenodd" d="M5 68C1 59 31 3 41 3s40 56 36 65c-5 9-67 9-72 0m13-8c3 6 43 6 46 0S47 17 41 17 15 54 18 60m11-8c-1-3 9-21 12-21s13 18 12 21c-2 3-22 3-24 0"/>
      </svg>
    '';
  };

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
