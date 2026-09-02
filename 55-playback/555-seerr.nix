# ---
# id: "555-seerr"
# title: "Seerr — Request Management"
# domain: 55
# last_reviewed: 2026-09-02
# sprite: 50-core/icons.svg#seerr
# provides: ["seerr"]
# adr: ADR-5610
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.seerr;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.seerr;
  port = reg.port;
  uid = reg.uid;
  gid = reg.gid;
  stateDir = reg.stateDir;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  seerrPkg =
    if cfg.package != null then cfg.package
    else if pkgs ? seerr then pkgs.seerr
    else if pkgs ? jellyseerr then pkgs.jellyseerr
    else pkgs.overseerr;
in
lib.mkIf cfg.enable {
  users.users.seerr = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.seerr = {
    after = [ "network.target" "jellyfin.service" ];
    requires = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      profiles.dotnet
      {
        ExecStart = lib.getExe seerrPkg;
        User = "seerr";
        Group = "media";
        UMask = "0002";
        StateDirectory = "seerr-${toString port}";
        ReadWritePaths = [ stateDir ];
      }
      (lib.mkIf (cfg.envFile or null != null) {
        EnvironmentFile = cfg.envFile;
      })
      (lib.mkIf (svc.secrets.seerrApiKeyFile or null != null) {
        LoadCredentialEncrypted = [ "seerr-api-key:${svc.secrets.seerrApiKeyFile}" ];
      })
    ];
    environment = {
      PORT = toString port;
      HOST = "127.0.0.1";
    };
  };

  medinix.ingress.vhosts."seerr" = { accessGroup = "public"; };
}
