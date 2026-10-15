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
  stateDir ? null, # z. B. "/var/lib/jellyfin" (ADR-0000 §9: ohne Port-Suffix)
  profile ? "base", # hardening profile name (from registry.hardeningProfile)
  allowedPeers ? [ ], # service names whose stateDir is reachable (e.g. ["sabnzbd" "prowlarr"])
  extraConfig ? { }, # additional serviceConfig fields (service-specific deviations)
  hardeningOnly ? false, # return only serviceConfig for NixOS upstream modules
  ownsAccount ? true, # false = die Engine besitzt users.users.<name> (Manifest-Dienst)
  mediaGroup ? false, # true = zusaetzlich extraGroups = [ "media" ] (geteilte Medienablage)
  offloadMediaCover ? false, # offload MediaCover to metadataDir via systemd BindPaths
  ...
}:
let
  metadataDir = toString (config.medinix.storage.metadataDir or "/var/lib/media-metadata");
  useMediaCover =
    offloadMediaCover && (config.medinix.storage.offloadMediaCover or true) && (stateDir != null);
  mediaCoverSource = "${metadataDir}/${name}-MediaCover";
  # Gruppe des privaten State-Verzeichnisses: bei Fabrik-eigenem Account die UPG
  # (Unit-Name). Vorher stand hier fest "media" (ADR-0000 §4: kein Peer darf ein
  # fremdes /var/lib/<name> lesen).
  stateDirGroup = if ownsAccount then name else "media";
in
if hardeningOnly then
  {
    serviceConfig = lib.mkMerge [
      {
        SyslogIdentifier = name;
        StandardOutput = "journal";
        StandardError = "journal";
        SystemCallErrorNumber = "EPERM";
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
      # 2) Service-spezifische Basis - NUR wenn die Fabrik den Account besitzt
      #    (hardeningOnly + ownsAccount, z. B. 513). Upstream-Module (512/581/582)
      #    setzen User/Group selbst und kommen mit ownsAccount = false.
      #    Ohne das lief die Unit als ROOT (gemessen 2026-10-15: 513).
      (lib.optionalAttrs ownsAccount {
        User = name;
        Group = name; # UPG (ADR-0000 §4): Primaergruppe = Unit-Name, GID = uid
        RuntimeDirectory = name;
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
          SystemCallErrorNumber = "EPERM";
        }
        # 1) Zentrales Hardening-Profil (ADR-5050) — nie per-Modul dupliziert
        (profiles.${profile} or profiles.base)
        # 1b) Zentrale Memory- & OOM-Policy (lib/memory-policy.nix)
        (memoryPolicy.${name} or memoryPolicy.default)
        # 2) Service-spezifische Basis (User/Exec/State)
        {
          User = "${name}";
          ExecStart = execStart;
          StateDirectory = lib.removePrefix "/var/lib/" stateDir;
          StateDirectoryMode = "0750"; # owner rw, group r, world nichts (NIXH-40-MED)
          RuntimeDirectory = name;
        }
        # Group: UPG (ADR-0000 §4) - Primaergruppe = Unit-Name, GID = uid.
        # Fuer Manifest-Dienste setzt die Engine sie, fuer Fabrik-eigene Units
        # (caddy-media) setzen wir sie hier.
        (lib.optionalAttrs ownsAccount { Group = name; })
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
    # BindPaths requires BOTH sides (source AND destination mountpoint) to exist before namespace setup.
    # Parent state directory must ALWAYS be declared first to prevent implicit root:root ownership.
    systemd.tmpfiles.rules =
      lib.optionals (stateDir != null) [
        "d '${stateDir}' 0750 ${name} ${stateDirGroup} -"
      ]
      ++ lib.optionals useMediaCover [
        "d '${stateDir}/MediaCover' 0775 ${name} media -"
        "d '${mediaCoverSource}' 0775 ${name} media -"
      ];
    medinix.knownStateDirs = [ stateDir ];
    medinix.factoryUnits."${name}" = { inherit uid stateDir; };
  }
  // lib.optionalAttrs ownsAccount {
    # Nur fuer Units OHNE Manifest-Eintrag: sonst besitzt die Engine den Account.
    # UPG wie bei der Engine (ADR-0000 §4): Primaergruppe = Unit-Name, GID = uid.
    # Die geteilte Gruppe media (5000) ist ausschliesslich supplementary und wird
    # nur mit mediaGroup = true vergeben.
    users.groups."${name}" = {
      gid = uid;
    };
    users.users."${name}" = {
      inherit uid;
      group = name;
      extraGroups = lib.optional mediaGroup "media";
      isSystemUser = true;
      home = stateDir;
      createHome = true;
    };
  }
