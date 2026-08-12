# ---
# id: "service-factory"
# title: "Systemd-native Service Factory (mkService, isolation=systemd-only)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-0000, ADR-5050
# provides: ["mkService"]
# requires: ["./hardening-profiles.nix", "./registry.nix"]
# ports: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# ---
#
# lib/service-factory.nix — Systemd-native Service Factory
# Generates a systemd service from a descriptor attrset. No docker, no netns.
# Hardening comes from lib/hardening-profiles.nix (profile selected in registry).
{ lib, config, ... }:

let
  profiles = import ./hardening-profiles.nix { inherit lib; };
  registry = (import ./registry.nix { inherit lib; }).services;

  # Generiere InaccessiblePaths für fremde State-Dirs (außer allowedPeers).
  # Jeder Dienst sieht nur seine eigenen + erlaubte Peer-State-Dirs.
  mkPeerIsolation = selfName: allowedPeers:
    let
      allStateDirs = lib.mapAttrsToList (n: svc:
        lib.optional (svc.stateDir != null && n != selfName && !(lib.elem n allowedPeers))
          svc.stateDir
      ) registry;
    in
      lib.flatten allStateDirs;
in
{ name            # service name (kebab-case)
, port            # port number from registry
, uid             # UID from registry
, execStart       # the start command as string
, stateDir        # e.g. "/var/lib/jellyfin-5510"
, profile ? "base" # hardening profile name (from registry.hardeningProfile)
, allowedPeers ? [] # service names whose stateDir is reachable (e.g. ["sabnzbd" "prowlarr"])
, extraConfig ? {} # additional serviceConfig fields (service-specific deviations)
}:
{
  systemd.services."${name}" = {
    wantedBy = [ "multi-user.target" ];
    after    = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    serviceConfig = lib.mkMerge [
      # 1) Zentrales Hardening-Profil (ADR-5050) — nie per-Modul dupliziert
      (profiles.${profile} or profiles.base)
      # 2) Service-spezifische Basis (User/Exec/State)
      {
        User             = "${name}";
        Group            = "media";
        ExecStart        = execStart;
        StateDirectory   = lib.removePrefix "/var/lib/" stateDir;
        StateDirectoryMode = "0750";  # owner rw, group media r, world nichts (NIXH-40-MED)
        RuntimeDirectory = name;
      }
      # 3) Peer-Isolation: fremde State-Dirs unsichtbar machen (außer allowedPeers)
      (lib.optionalAttrs (allowedPeers != []) {
        InaccessiblePaths = mkPeerIsolation name allowedPeers;
      })
      # 4) Pro-Dienst-Abweichungen (ReadWritePaths, DeviceAllow, etc.)
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
