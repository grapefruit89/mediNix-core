# ---
# id: "581-ntfy"
# title: "ntfy — internal notification backend"
# domain: 58
# folder: 58-observability
# status: active
# complexity: 3
# last_reviewed: 2026-09-02
# requires: ["lib/hardening-profiles", "lib/registry"]
# systemd_hardened: true
# ---
# Loopback only. accessGroup=internal. ntfy itself is read-write; Caddy is the wall.
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
  ntfyGroup = svc.ingress.vhosts.ntfy.accessGroup or "internal";
in lib.mkIf cfg.enable {
  assertions = [{
    assertion = !lib.elem ntfyGroup [ "public" "stream" "idp" ];
    message = ''
      [mediNix] ntfy is an internal backend. accessGroup must stay internal or none.
      auth-default-access is read-write. WAN exposure would be unauthenticated.
    '';
  }];

  users.users.ntfy = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };

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
      auth-default-access = "read-write";
    };
  };

  systemd.services.ntfy-sh = {
    unitConfig.RequiresMountsFor = [ stateDir ];
    serviceConfig = lib.mkMerge [ profiles.network { User = "ntfy"; Group = "media"; } ];
  };

  medinix.ingress.vhosts."ntfy" = { accessGroup = "internal"; };
}
