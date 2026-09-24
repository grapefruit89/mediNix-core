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
# requires: []
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
  memoryPolicy = import ./memory-policy.nix { inherit lib; };

  # Generiere InaccessiblePaths für fremde State-Dirs (außer allowedPeers).
  # Jeder Dienst sieht nur seine eigenen + erlaubte Peer-State-Dirs.
  mkPeerIsolation =
    selfName: selfStateDir: allowedPeers:
    let
      allStateDirs = lib.mapAttrsToList (
        n: svc:
        lib.optional (
          (svc.stateDir or null) != null
          && n != selfName
          # The unit name can differ from the registry key (unit "caddy-media"
          # vs registry "caddy"). Exclude by the actual own stateDir too, so a
          # unit never makes its OWN StateDirectory inaccessible (H29).
          && svc.stateDir != selfStateDir
          && !(lib.elem n allowedPeers)
        ) svc.stateDir
      ) registry;
    in
    # "-" prefix (systemd.exec): ignore the entry when the path does not exist.
    # A foreign state dir is absent until that service has run at least once;
    # without the prefix systemd aborts the unit with 226/NAMESPACE.
    map (p: "-${p}") (lib.flatten allStateDirs);
in
{
  name, # service name (kebab-case)
  uid ? null, # UID from registry
  execStart ? null, # the start command as string
  stateDir ? null, # e.g. "/var/lib/jellyfin-5510"
  profile ? "base", # hardening profile name (from registry.hardeningProfile)
  allowedPeers ? [ ], # service names whose stateDir is reachable (e.g. ["sabnzbd" "prowlarr"])
  extraConfig ? { }, # additional serviceConfig fields (service-specific deviations)
  hardeningOnly ? false, # return only serviceConfig for NixOS upstream modules
  offloadMediaCover ? false, # offload MediaCover to metadataDir via systemd BindPaths
  ...
}:
let
  metadataDir = toString (config.medinix.storage.metadataDir or "/var/lib/media-metadata");
  useMediaCover =
    offloadMediaCover && (config.medinix.storage.offloadMediaCover or true) && (stateDir != null);
  mediaCoverSource = "${metadataDir}/${name}-MediaCover";
in
if hardeningOnly then
  {
    serviceConfig = lib.mkMerge [
      {
        SyslogIdentifier = name;
        StandardOutput = "journal";
        StandardError = "journal";
      }
      (profiles.${profile} or profiles.base)
      (memoryPolicy.${name} or memoryPolicy.default)
      (lib.optionalAttrs (stateDir != null) {
        StateDirectory = lib.removePrefix "/var/lib/" stateDir;
        StateDirectoryMode = "0750";
      })
      (
        let
          paths = mkPeerIsolation name stateDir allowedPeers;
        in
        lib.optionalAttrs (paths != [ ]) {
          InaccessiblePaths = paths;
        }
      )
      (lib.optionalAttrs useMediaCover {
        ReadWritePaths = [ mediaCoverSource ];
        BindPaths = [ "${mediaCoverSource}:${stateDir}/MediaCover" ];
      })
      extraConfig
    ];
  }
else
  {
    systemd.services."${name}" = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      requires = [ "network.target" ];
      serviceConfig = lib.mkMerge [
        # 0) Standard-Logging: alles in Journal (kein /var/log-File, kein stdout-Verlust)
        {
          SyslogIdentifier = name;
          StandardOutput = "journal";
          StandardError = "journal";
        }
        # 1) Zentrales Hardening-Profil (ADR-5050) — nie per-Modul dupliziert
        (profiles.${profile} or profiles.base)
        # 1b) Zentrale Memory- & OOM-Policy (lib/memory-policy.nix)
        (memoryPolicy.${name} or memoryPolicy.default)
        # 2) Service-spezifische Basis (User/Exec/State)
        {
          User = "${name}";
          Group = "media";
          ExecStart = execStart;
          StateDirectory = lib.removePrefix "/var/lib/" stateDir;
          StateDirectoryMode = "0750"; # owner rw, group media r, world nichts (NIXH-40-MED)
          RuntimeDirectory = name;
        }
        # 3) Peer-Isolation: fremde State-Dirs unsichtbar machen (außer allowedPeers)
        (
          let
            paths = mkPeerIsolation name stateDir allowedPeers;
          in
          lib.optionalAttrs (paths != [ ]) {
            InaccessiblePaths = paths;
          }
        )
        # 3b) MediaCover offloading (State != Cache) via BindPaths
        (lib.optionalAttrs useMediaCover {
          ReadWritePaths = [ mediaCoverSource ];
          BindPaths = [ "${mediaCoverSource}:${stateDir}/MediaCover" ];
        })
        # 4) Pro-Dienst-Abweichungen (ReadWritePaths, DeviceAllow, etc.)
        extraConfig
      ];
    };
    # BindPaths requires BOTH sides (source AND destination mountpoint) to exist before namespace setup
    systemd.tmpfiles.rules = lib.optionals useMediaCover [
      "d '${stateDir}' 0750 ${name} media -"
      "d '${stateDir}/MediaCover' 0775 ${name} media -"
      "d '${mediaCoverSource}' 0775 ${name} media -"
    ];
    medinix.knownStateDirs = [ stateDir ];
    medinix.factoryUnits."${name}" = { inherit uid stateDir; };
    users.users."${name}" = {
      inherit uid;
      group = "media";
      isSystemUser = true;
      home = stateDir;
      createHome = true;
    };
  }
