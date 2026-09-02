# ---
# id: "553-navidrome"
# title: "Navidrome — Music Server"
# domain: 55
# last_reviewed: 2026-09-02
# sprite: 50-core/icons.svg#navidrome
# adr: ADR-5530
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.navidrome;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  creds = import ../lib/creds.nix { inherit lib; };
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
        InaccessiblePaths = [ creds.storeDir ];
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

  medinix.ingress.vhosts."navidrome" = { accessGroup = "stream"; };
}
