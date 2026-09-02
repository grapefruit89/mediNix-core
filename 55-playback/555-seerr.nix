# ---
# id: "555-seerr"
# title: "Seerr — Request Management"
# domain: 55
# folder: 55-playback
# status: active
# last_reviewed: 2026-09-02
# provides: ["seerr"]
# requires: ["lib/hardening-profiles", "lib/registry"]
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

  medinix.ingress.vhosts."seerr" = {
    accessGroup = "public";
    landing = true;
    iconSvg = ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">
        <circle cx="48" cy="48" r="48" fill="#4f65f5"/>
        <circle cx="52" cy="52" r="28" fill="#131928"/>
        <circle cx="38" cy="38" r="14" fill="#c395fc"/>
      </svg>
    '';
  };
}
