# ---
# id: "552-audiobookshelf"
# title: "Audiobookshelf — Audiobooks & Podcasts (55-playback, Dienst 552)"
# domain: 55
# folder: 55-playback
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5520
#   skill: nixos-context7-gate
#   gold: CLAUDE.md (seccomp SIGSYS → SystemCallErrorNumber=EPERM; 200 expected)
# context7:
#   - query: "systemd.services serviceConfig SystemCallErrorNumber SystemCallFilter example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "SystemCallFilter + SystemCallErrorNumber=EPERM to avoid silent SIGSYS kill"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.audiobookshelf;
  svc = config.grapefruitMedia;
  port = 5520;  # 552 × 10
  uid  = 5520;
  gid  = 5000;
  stateDir   = "/var/lib/audiobookshelf-${toString port}";
  metadataDir = "${svc.storage.metadataDir}/audiobookshelf";
in
{
  users.users.audiobookshelf = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.audiobookshelf = {
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.audiobookshelf}/bin/audiobookshelf";
      User = "audiobookshelf";
      Group = "media";
      UMask = "002";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      StateDirectory = "audiobookshelf-${toString port}";
      # Tier 2 metadata (rw) + Tier 3 media (rw, ABS writes covers)
      ReadWritePaths = [ stateDir metadataDir "${svc.storage.mediaRoot}/audiobooks" ];
      # CLAUDE.md gold: seccomp SIGSYS kills silently → EPERM instead
      SystemCallFilter = [ "@system-service" ];
      SystemCallErrorNumber = "EPERM";
    };
    environment = {
      PORT = toString port;
      CONFIG_PATH = stateDir;
      METADATA_PATH = metadataDir;
      AUDIOBOOKS_PATH = "${svc.storage.mediaRoot}/audiobooks";
    };
  };
}
