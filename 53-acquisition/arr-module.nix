# ---
# id: "arr-module"
# title: "Universelle Servarr-Modul-Factory (Sonarr/Radarr/Readarr/Lidarr/Prowlarr)"
# domain: 53
# folder: 53-acquisition
# status: active
# kind: library
# complexity: 3
# last_reviewed: 2026-11-26
# anchors: ["gof-factory-method-pattern", "dry", "twelve-factor-app", "least-privilege"]
# links:
#   adr: ADR-532, ADR-5050
# provides: ["arr-module", "53-acquisition/arr-module"]
# requires: ["53-acquisition/arr-settings", "53-acquisition/arr-key-sync", "51-ingress/ingress-access", "50-core/service-factory", "50-core/registry", "50-core/hardening-profiles", "50-core/memory-policy"]
# ---
{
  lib,
  config,
  pkgs,
}:
{
  name,
  title,
  description,
  icon ? name,
  binaryName,
  role ? "media-manager",
  category ? null,
  apiVersion ? if name == "sonarr" || name == "radarr" then "v3" else "v1",
  ramBudget ? "1.5G",
  allowedPeers ? [
    "sabnzbd"
    "prowlarr"
  ],
  healthPath ? "/api/${apiVersion}/system/status",
  updateMechanism ? if role == "indexer" then "External" else "BuiltIn",
  offloadMediaCover ? role == "media-manager",
  opsNotes ? "Arr-${title}-Management mit Prowlarr- und SABnzbd-Kopplung.",
  enableDescription ? "${title} Manager",
  extraOptions ? { },
  extraServiceConfig ? { },
  extraSystemdService ? { },
}:

let
  cfg = config.medinix.${name};
  svc = config.medinix;
  keySync = import ./arr-key-sync.nix {
    inherit pkgs name;
  };
  registry = (import ../50-core/registry.nix { inherit lib; }).services;
  reg = registry.${name};
  meta = config.medinix.manifest.${name};

  inherit (meta) port uid stateDir;
  inherit (reg) sharedGid;
  mkService = import ../50-core/service-factory.nix { inherit lib config; };
  arrSettings = import ./arr-settings.nix { inherit lib; };

  package = if cfg.package != null then cfg.package else pkgs.${name};

  # F2: Forward-auth detection follows the RESOLVED exposure — EIN Produzent
  # (51-ingress/ingress-access.nix) statt einer vierten Kopie der Regel.
  exposedPublic =
    (import ../51-ingress/ingress-access.nix { inherit lib; }).accessGroupOf svc name meta == "public";
  authMethod =
    if (config.medinix.ingress.auth.mode == "forward-auth" && exposedPublic) then
      "External"
    else
      "Forms";

  apiKeyFile = svc.secrets."${name}ApiKeyFile" or null;
in
{
  options.medinix.${name} = {
    enable = lib.mkEnableOption enableDescription;

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "null";
      description = ''
        Optionales Paket-Override für ${title}.
        null = NixOS-Modul-Default aus nixpkgs.
      '';
    };
  }
  // extraOptions;

  config = lib.mkMerge [
    # ── 1. SERVICE-MANIFEST (Top-Level: Immer im Katalog, SSoT) ─────────────
    {
      medinix.manifest.${name} = {
        inherit (cfg) enable;
        inherit (reg) num;
        accessGroup = "internal";

        ui = {
          inherit title description icon;
          group = "Acquisition";
        };

        monitoring = {
          inherit (cfg) enable;
          type = "http";
          inherit healthPath;
          expectedStatus = 200;
        };

        metrics = {
          inherit (cfg) enable;
          type = "exportarr";
        };

        arr = {
          inherit role apiVersion;
        }
        // lib.optionalAttrs (category != null) { inherit category; };

        ops = {
          priority = "medium";
          inherit ramBudget;
          notes = opsNotes;
        };
      };
    }

    # ── 2. RUNTIME & SYSTEMD (Nur aktiv wenn cfg.enable = true) ─────────────
    (lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          assertions = [
            {
              assertion = meta.num == reg.num;
              message = "[mediNix/${toString reg.num}-${name}] Manifest-Nummer (${toString meta.num}) stimmt nicht mit 50-core/registry.nix (${toString reg.num}) überein!";
            }
          ];

          users.groups.media.gid = sharedGid;
        }
        (mkService {
          inherit
            name
            port
            uid
            stateDir
            offloadMediaCover
            allowedPeers
            ;
          ownsAccount = false; # users.users.<name> besitzt die Engine (UPG)
          execStart = "${package}/bin/${binaryName} -nobrowser -data=${stateDir}";
          profile = "dotnet";
          extraConfig = lib.mkMerge [
            {
              User = name;
              UMask = "0002";
              ReadWritePaths = [
                stateDir
              ]
              ++ lib.optional (role == "media-manager") config.medinix.storage.mediaRoot;
            }
            extraServiceConfig
          ];
        })
        {
          systemd.services.${name} = lib.mkMerge [
            {
              after = [ "network.target" ] ++ lib.optionals (role == "media-manager") [ "prowlarr.service" ];
              requires = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];
              onFailure = [ "alert-ntfy@%n.service" ];
              environment = arrSettings.mkArrEnv (lib.toUpper name) {
                server = {
                  inherit port;
                  bindAddress = "127.0.0.1";
                  urlBase = "";
                };
                auth = {
                  method = authMethod;
                  required = "Enabled";
                };
                app = {
                  theme = "dark";
                  instanceName = title;
                };
                log.level = "info";
                log.consoleLevel = "debug";
                update.mechanism = updateMechanism;
              };
            }
            (lib.mkIf (apiKeyFile != null) {
              serviceConfig = {
                LoadCredentialEncrypted = [ "${name}-api-key:${apiKeyFile}" ];
                # Die App ignoriert Env-Overrides fuer ApiKey; der versiegelte
                # Wert wird deshalb vor dem Start in config.xml geschrieben.
                ExecStartPre = [ "${keySync}/bin/arr-api-key-sync-${name}" ];
              };
            })
            extraSystemdService
          ];

          systemd.sockets.${name} = lib.mkIf svc.onDemand.enable {
            wantedBy = [ "sockets.target" ];
            listenStreams = [ "127.0.0.1:${toString port}" ];
            socketConfig.Accept = false;
          };
        }
      ]
    ))
  ];
}
