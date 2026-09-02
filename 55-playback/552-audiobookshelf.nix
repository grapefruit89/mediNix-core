# ---
# id: "552-audiobookshelf"
# title: "Audiobookshelf"
# domain: 55
# folder: 55-playback
# status: active
# last_reviewed: 2026-09-02
# adr: ADR-5520
# ---
# WAN stream. App login. Logo: logos/audiobookshelf.svg → 518 #audiobookshelf.
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.audiobookshelf;
  svc = config.medinix;
  creds = import ../lib/creds.nix { inherit lib; };
  port = 5520;
  uid = 5520;
  gid = 5000;
  stateDir = "/var/lib/audiobookshelf-${toString port}";
  metadataDir = "${svc.storage.metadataDir}/audiobookshelf";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in
lib.mkIf cfg.enable {
  users.users.audiobookshelf = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.audiobookshelf = {
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      profiles.nodejs
      {
        ExecStart = "${pkgs.audiobookshelf}/bin/audiobookshelf";
        User = "audiobookshelf";
        Group = "media";
        UMask = "0002";
        StateDirectory = "audiobookshelf-${toString port}";
        ReadWritePaths = [ stateDir metadataDir ];
        BindReadOnlyPaths = [ "${svc.storage.mediaRoot}/audiobooks:${svc.storage.mediaRoot}/audiobooks" ];
        InaccessiblePaths = [ creds.storeDir ];
      }
    ];
    environment = {
      PORT = toString port;
      CONFIG_PATH = stateDir;
      METADATA_PATH = metadataDir;
      AUDIOBOOKS_PATH = "${svc.storage.mediaRoot}/audiobooks";
    };
  };

  medinix.ingress.vhosts."audiobookshelf" = {
    accessGroup = "stream";
    landing = true;
    iconId = "audiobookshelf";
  };
}
