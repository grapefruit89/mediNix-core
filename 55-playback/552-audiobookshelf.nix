# ---
# id: "552-audiobookshelf"
# title: "Audiobookshelf"
# domain: 55
# folder: 55-playback
# status: active
# last_reviewed: 2026-09-02
# adr: ADR-5520
# ---
# WAN stream vhost. Users log into ABS itself. No Pocket-ID / Caddy SSO.
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.audiobookshelf;
  svc = config.medinix;
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
        ReadWritePaths = [ stateDir metadataDir "${svc.storage.mediaRoot}/audiobooks" ];
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
    iconSvg = ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
        <circle cx="255.5" cy="256" r="247.4" fill="#cd9d49" stroke="#f0f0f8" stroke-width="16"/>
      </svg>
    '';
  };
}
