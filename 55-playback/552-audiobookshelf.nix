# ---
# id: "552-audiobookshelf"
# title: "Audiobookshelf — Audiobooks & Podcasts (55-playback, Service 552)"
# domain: 55
# folder: 55-playback
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links: https://audiobookshelf.org/
# provides: []
# requires: ["lib/hardening-profiles"]
# ports: []
# upstream_docs: [https://audiobookshelf.org/docs/documentation/introduction/]
# forum_links: []
# upstream_github: "https://github.com/advplyr/audiobookshelf"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5520, ADR-5050
# skill: nixos-context7-gate
# gold: CLAUDE.md (seccomp SIGSYS → SystemCallErrorNumber=EPERM; 200 expected)
# context7: https://context7.com/advplyr/audiobookshelf,  https://context7.com/websites/audiobookshelf, https://context7.com/audiobookshelf/audiobookshelf-api-docs, https://context7.com/audiobookshelf/audiobookshelf-web
# - query: "systemd.services serviceConfig SystemCallErrorNumber SystemCallFilter example"
# library: /websites/nixos_manual_nixos_unstable
# snippet: "SystemCallFilter + SystemCallErrorNumber=EPERM to avoid silent SIGSYS kill"
# svg logo: https://github.com/grapefruit89/logorepo/blob/main/audiobookshelf.svg
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.audiobookshelf;
  svc = config.medinix;
  port = 5520;  # 552 × 10
  uid  = 5520;
  gid  = 5000;
  stateDir   = "/var/lib/audiobookshelf-${toString port}";
  metadataDir = "${svc.storage.metadataDir}/audiobookshelf";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in
lib.mkIf (cfg.enable) {
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
      # nodejs profile: MemoryDenyWriteExecute=false (V8 JIT), PrivateDevices=true
      profiles.nodejs
      {
        ExecStart = "${pkgs.audiobookshelf}/bin/audiobookshelf";
        User = "audiobookshelf";
        Group = "media";
        UMask = "0002";
        StateDirectory = "audiobookshelf-${toString port}";
        # Tier 2 metadata (rw) + Tier 3 media (rw, ABS writes covers)
        ReadWritePaths = [ stateDir metadataDir "${svc.storage.mediaRoot}/audiobooks" ];
        # CLAUDE.md gold: seccomp SIGSYS kills silently → EPERM via Profil (base)
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
    accessGroup = reg.caddyClass;
    landing = true;
    iconSvg = ''
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 512 512">
        <linearGradient id="a" x2="0" y2="1">
          <stop offset=".3" stop-color="#cd9d49"/>
          <stop offset="1" stop-color="#875d27"/>
        </linearGradient>
        <circle cx="255.5" cy="256" r="247.4" fill="url(#a)" stroke="#f0f0f8" stroke-width="16" paint-order="stroke"/>
        <path fill="#f0f0f8" d="M245.2 46.9a151.3 151.3 0 0 0-141 150.9v32.8l-9.4 7a8 8 0 0 0-2.7 5.8v39.3q0 3.4 2.7 5.8c4.7 3.9 15.4 12 32.1 20.4v3.8c0 10.3 6.6 18.6 14.8 18.6s14.8-8.4 14.8-18.6v-94.2c0-10.3-6.6-18.6-14.8-18.6-7.9 0-14.3 7.7-14.8 17.3v-19.4a128.6 128.6 0 0 1 257.2 0v19.4c-.5-9.7-7-17.3-14.8-17.3-8.2 0-14.8 8.4-14.8 18.6v94.2c0 10.3 6.6 18.6 14.8 18.6s14.8-8.4 14.8-18.6v-3.8a172 172 0 0 0 32.1-20.4 8 8 0 0 0 2.7-5.8v-39.3q-.2-3.6-2.7-5.8-3-2.6-9.4-7v-32.8c0-87.6-74.2-156.9-161.6-150.9"/>
        <use xlink:href="#b" transform="translate(62)"/>
        <use xlink:href="#b" transform="translate(-62)"/>
        <path id="b" fill="#f0f0f8" d="M246.2 164.9c-9.9 0-17.9 8-17.9 17.9v200.6c0 9.9 8 17.9 17.9 17.9h18.5c9.9 0 17.9-8 17.9-17.9V182.8c0-9.9-8-17.9-17.9-17.9zM235.1 213h40.8v4.3h-40.8z"/>
        <path fill="none" stroke="#f0f0f8" stroke-linecap="round" stroke-width="27" d="M135.4 421h252.8" paint-order="fill markers stroke"/>
      </svg>
    '';
  };
}

