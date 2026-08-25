# ---
# id: "581-ntfy"
# title: "ntfy.sh - Push Notifications for Arr-Stack + Jellyfin (58-observability, Service 581)"
# domain: 58
# folder: 58-observability
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.observability.ntfy;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.ntfy;
  port = reg.port;
  uid = reg.uid;
  gid = reg.gid;
  stateDir = reg.stateDir;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in lib.mkIf cfg.enable {
  users.users.ntfy = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };

  # Protect SSD with tmpfs for ntfy state
  systemd.mounts = [{
    what = "tmpfs";
    where = stateDir;
    type = "tmpfs";
    options = "size=256M,mode=0750,uid=${toString uid},gid=${toString gid}";
  }];

  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = cfg.baseUrl;
      listen-http = "127.0.0.1:${toString port}";
      cache-file = "${stateDir}/cache.db";
      attachment-cache-dir = "${stateDir}/attachments";
      # Enforce auth if public, otherwise rely on VPN
      auth-default-access = "read-write";
    };
  };

  systemd.services.ntfy-sh = {
    unitConfig.RequiresMountsFor = [ stateDir ];
    serviceConfig = lib.mkMerge [ profiles.network { User = "ntfy"; Group = "media"; } ];
  };

  medinix.ingress.vhosts."ntfy" = { accessGroup = "internal"; };
}
