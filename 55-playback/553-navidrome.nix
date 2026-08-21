# ---
# id: "553-navidrome"
# title: "Navidrome — Music Server (55-playback, Service 553)"
# domain: 55
# folder: 55-playback
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5530, ADR-5050
#   skill: nixos-context7-gate
#   gold: CLAUDE.md (media group via mkAfter — sonst silent empty library)
# context7:
#   - query: "systemd.services serviceConfig BindReadOnlyPaths example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "BindReadOnlyPaths for read-only media mount"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.navidrome;
  svc = config.grapefruitMedia;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.navidrome;
  port = reg.port;
  uid = reg.uid;
  gid = reg.gid;
  stateDir = reg.stateDir;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
in
lib.mkIf (cfg.enable) {
  users.users.navidrome = {
    uid = uid; group = "media";
    # CLAUDE.md gold: media group MUST be present or library is silently empty
    extraGroups = lib.mkAfter [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.navidrome = {
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      # nodejs profile: MemoryDenyWriteExecute=false (V8 JIT), PrivateDevices=true
      profiles.nodejs
      {
        ExecStart = "${pkgs.navidrome}/bin/navidrome --configfile ${stateDir}/navidrome.toml";
        User = "navidrome";
        Group = "media";
        UMask = lib.mkForce "0002";
        StateDirectory = "navidrome-${toString port}";
        # Tier 1 state + Tier 3 music (read-only)
        ReadWritePaths = [ stateDir ];
        BindReadOnlyPaths = [ "${svc.storage.mediaRoot}/music:${svc.storage.mediaRoot}/music" ];
      }
    ];
    # OIDC via EnvironmentFile (ADR-5000: no inline secrets)
    environment = {
      ND_PORT = toString port;
      ND_ADDRESS = "127.0.0.1";
      ND_MUSICFOLDER = "${svc.storage.mediaRoot}/music";
      ND_DATAFOLDER = stateDir;
    } // lib.optionalAttrs (cfg.oidcFile or null != null) {
      ND_OIDC_CLIENT_ID_FILE = cfg.oidcFile;
    };
  };

  grapefruitMedia.ingress.vhosts."navidrome" = { accessGroup = reg.caddyClass; };
}

