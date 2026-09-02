# ---
# id: "553-navidrome"
# title: "Navidrome — Music Server"
# domain: 55
# folder: 55-playback
# status: active
# last_reviewed: 2026-09-02
# requires: ["lib/hardening-profiles", "lib/registry"]
# adr: ADR-5530
# ---
# WAN stream vhost. Login is Navidrome users. No Pocket-ID OIDC unless the
# host sets secrets.navidromeOidcFile *and* wires it — this module does not.
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.navidrome;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.navidrome;
  port = reg.port;
  uid = reg.uid;
  gid = reg.gid;
  stateDir = reg.stateDir;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in
lib.mkIf cfg.enable {
  users.users.navidrome = {
    uid = uid; group = "media";
    extraGroups = lib.mkAfter [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.navidrome = {
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      profiles.nodejs
      {
        ExecStart = "${pkgs.navidrome}/bin/navidrome --configfile ${stateDir}/navidrome.toml";
        User = "navidrome";
        Group = "media";
        UMask = "0002";
        StateDirectory = "navidrome-${toString port}";
        ReadWritePaths = [ stateDir ];
        BindReadOnlyPaths = [ "${svc.storage.mediaRoot}/music:${svc.storage.mediaRoot}/music" ];
      }
    ];
    environment = {
      ND_PORT = toString port;
      ND_ADDRESS = "127.0.0.1";
      ND_MUSICFOLDER = "${svc.storage.mediaRoot}/music";
      ND_DATAFOLDER = stateDir;
      ND_ENABLEUSERSONSIGNUP = "false";
    };
  };

  medinix.ingress.vhosts."navidrome" = {
    accessGroup = "stream";
    landing = true;
    iconSvg = ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
        <circle cx="256" cy="256" r="245.5" fill="#0084ff" stroke="#000" stroke-width="21"/>
        <circle cx="256" cy="256" r="87.8" fill="#fff" stroke="#000" stroke-width="20"/>
      </svg>
    '';
  };
}
