# ---
# id: "55x-example"
# title: "Example service — copy this file, never edit 511/518 for a new app"
# domain: 55
# folder: 55-playback
# status: template
# ---
# Logos live in github.com/grapefruit89/logorepo (logos/<name>.svg).
# Service key == filename == symbol id. 518 renders <use href="/icons.svg#name">.
# Tile only if landing=true and accessGroup is stream|public|idp (WAN).
#
# accessGroup:
#   stream    media — no compress, long timeouts, no auth
#   internal  LAN only — no family tile
#   public    WAN+LAN — forward_auth if auth.mode = forward-auth
#   idp       Pocket ID
#   none      no vhost
{ config, lib, pkgs, ... }:

let
  name = "example";
  cfg  = config.medinix.${name};
  reg  = (import ../lib/registry.nix { inherit lib; }).services.${name};
in
lib.mkIf cfg.enable {
  systemd.services.${name} = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = lib.getExe pkgs.hello;
      User = name;
      Group = "media";
    };
    environment = {
      HOST = "127.0.0.1";
      PORT = toString reg.port;
    };
  };

  users.users.${name} = {
    uid = reg.uid;
    group = "media";
    isSystemUser = true;
    home = reg.stateDir;
    createHome = true;
  };

  medinix.ingress.vhosts.${name} = {
    accessGroup = reg.caddyClass;
    landing     = true;
    iconId      = name;   # optional; empty = vhost name = logorepo id
  };
}
