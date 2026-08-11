# ---
# id: "service-factory"
# title: "Systemd-native Service Factory (mkService, isolation=systemd-only)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-0000
# provides: ["mkService"]
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---

# lib/service-factory.nix — Systemd-native Service Factory
# Generates a systemd service from a descriptor attrset. No docker, no netns.
{ lib, config, ... }:

{ name            # service name (kebab-case)
, port            # port number from registry
, uid             # UID from registry
, execStart       # the start command as string
, stateDir        # e.g. "/var/lib/jellyfin-5510"
, extraConfig ? {} # additional serviceConfig fields
}:
{
  systemd.services."${name}" = {
    wantedBy = [ "multi-user.target" ];
    after    = [ "network.target" ];
    serviceConfig = lib.mkMerge [
      {
        User             = "${name}";
        Group            = "media";
        ExecStart        = execStart;
        StateDirectory   = lib.removePrefix "/var/lib/" stateDir;
        RuntimeDirectory = name;
        # systemd Hardening Baseline (ADR-5050)
        NoNewPrivileges       = true;
        ProtectSystem         = "strict";
        ProtectHome           = true;
        PrivateTmp            = true;
        PrivateDevices        = true;  # per-service overridable
        ProtectKernelModules  = true;
        ProtectKernelTunables = true;
        RestrictNamespaces   = true;
        RestrictRealtime     = true;
        LockPersonality      = true;
        MemoryDenyWriteExecute = true;
        SystemCallFilter      = "@system-service";
        Restart              = "on-failure";
        RestartSec           = "5s";
      }
      extraConfig
    ];
  };
  users.users."${name}" = {
    uid         = uid;
    group       = "media";
    isSystemUser = true;
    home        = stateDir;
    createHome  = true;
  };
}
