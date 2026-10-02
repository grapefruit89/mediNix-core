# ---
# id: "552-audiobookshelf"
# title: "Audiobookshelf"
# domain: 55
# last_reviewed: 2026-10-02
# sprite: 50-core/icons.svg#audiobookshelf
# adr: ADR-5520
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

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
  # RT-2 (first-run race): `stream` = WAN ohne Proxy-Auth. Audiobookshelf hat
  # KEINE env-basierte Admin-Erstellung — der erste Besucher des offenen
  # Setup-Screens wird Root-User. Resolved vHost-Exposure fragen (F2-Muster).
  exposedWan = builtins.elem (svc.ingress.vhosts."audiobookshelf".accessGroup or "none") [
    "stream"
    "public"
    "idp"
  ];
in
lib.mkIf cfg.enable {
  assertions = [
    {
      assertion = !exposedWan || cfg.setupCompleted;
      message = ''
        [mediNix] audiobookshelf is on the WAN stream vhost (no proxy auth)
        and its first-run setup screen is OPEN — any first visitor would
        become the root user (Audiobookshelf has no env-based admin pre-seed).
        Procedure: keep medinix.ingress.vhosts."audiobookshelf".accessGroup =
        "internal" (LAN-only, CIDR abort) while you complete the initial
        setup in the web UI, then set medinix.audiobookshelf.setupCompleted
        = true before exposing it as stream.
      '';
    }
  ];

  users.users.audiobookshelf = {
    inherit uid;
    group = "media";
    extraGroups = [ "media" ];
    home = stateDir;
    isSystemUser = true;
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
        ReadWritePaths = [
          stateDir
          metadataDir
        ];
        BindReadOnlyPaths = [ "${svc.storage.mediaRoot}/audiobooks:${svc.storage.mediaRoot}/audiobooks" ];
        InaccessiblePaths = [ "-${creds.storeDir}" ];
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
  };
}
