# ---
# id: "533-radarr"
# title: "Radarr — Movie Management (53-acquisition, Service 533)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# logo: https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/radarr.svg
# links:
#   adr: ADR-532, ADR-5050
# provides: []
# requires: ["lib/arr-settings", "lib/service-factory", "lib/registry", "lib/hardening-profiles", "lib/memory-policy"]
# adr: ADR-532, ADR-5050
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.radarr;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.radarr;
  meta = config.medinix.manifest.radarr;

  inherit (meta) port uid stateDir;
  inherit (reg) sharedGid;
  mkService = import ../lib/service-factory.nix { inherit lib config; };
  arrSettings = import ../lib/arr-settings.nix { inherit lib; };

  package = if cfg.package != null then cfg.package else pkgs.radarr;

  # F2: Forward-auth detection follows the RESOLVED exposure — EIN Produzent
  # (lib/ingress-access.nix) statt einer vierten Kopie der Regel.
  exposedPublic =
    (import ../lib/ingress-access.nix { inherit lib; }).accessGroupOf svc "radarr" meta == "public";
  authMethod =
    if (config.medinix.ingress.auth.mode == "forward-auth" && exposedPublic) then
      "External"
    else
      "Forms";
in
{
  options.medinix.radarr = {
    enable = lib.mkEnableOption "Radarr Movies Manager";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "null";
      description = ''
        Optionales Paket-Override für Radarr.
        null = NixOS-Modul-Default aus nixpkgs.
      '';
    };

    rootFolder = lib.mkOption {
      type = lib.types.str;
      default = svc.storage.mediaRoot + "/movies";
      description = "Arr root folder (API-configured via provisioning).";
    };

    qualityProfile = lib.mkOption {
      type = lib.types.str;
      default = "HD-1080p";
      description = "Arr quality profile name (API-configured via provisioning).";
    };
  };

  config = lib.mkMerge [
    # ── 1. SERVICE-MANIFEST (Top-Level: Immer im Katalog, SSoT) ─────────────
    {
      medinix.manifest.radarr = {
        inherit (cfg) enable;
        inherit (reg) num;
        accessGroup = "internal";

        ui = {
          title = "Radarr";
          description = "Filme-Verwaltung & Automatisierung";
          icon = "radarr";
          group = "Acquisition";
        };

        monitoring = {
          inherit (cfg) enable;
          type = "http";
          healthPath = "/api/v3/system/status";
          expectedStatus = 200;
        };

        metrics = {
          inherit (cfg) enable;
          type = "exportarr";
        };

        arr = {
          role = "media-manager";
          category = "movies";
        };

        ops = {
          priority = "medium";
          ramBudget = "1.5G";
          notes = "Arr-Filme-Management mit Prowlarr- und SABnzbd-Kopplung.";
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
              message = "[mediNix/533-radarr] Manifest-Nummer (${toString meta.num}) stimmt nicht mit lib/registry.nix (${toString reg.num}) überein!";
            }
          ];

          users.groups.media.gid = sharedGid;
        }
        (mkService {
          name = "radarr";
          ownsAccount = false; # users.users.radarr besitzt die Engine (UPG)
          inherit port;
          inherit uid;
          execStart = "${package}/bin/Radarr -nobrowser -data=${stateDir}";
          inherit stateDir;
          profile = "dotnet";
          offloadMediaCover = true;
          allowedPeers = [
            "sabnzbd"
            "prowlarr"
          ];
          extraConfig = {
            User = "radarr";
            UMask = "0002";
            ReadWritePaths = [
              stateDir
              config.medinix.storage.mediaRoot
            ];
          };
        })
        {
          systemd.services.radarr = {
            after = [
              "network.target"
              "prowlarr.service"
            ];
            requires = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            onFailure = [ "alert-ntfy@%n.service" ];
            environment = lib.mkMerge [
              (lib.mkIf (svc.secrets.radarrApiKeyFile or null != null) {
                RADARR_API_KEY_FILE = svc.secrets.radarrApiKeyFile;
              })
              (arrSettings.mkRadarr {
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
                  instanceName = "Radarr";
                };
                log.level = "info";
                log.consoleLevel = "debug";
                update.mechanism = "BuiltIn";
              })
            ];
          };

          systemd.sockets.radarr = lib.mkIf svc.onDemand.enable {
            wantedBy = [ "sockets.target" ];
            listenStreams = [ "127.0.0.1:${toString port}" ];
            socketConfig.Accept = false;
          };
        }
        {
          systemd.services."radarr" = lib.mkIf (svc.secrets.radarrApiKeyFile != null) {
            serviceConfig.LoadCredentialEncrypted = [ "radarr-api-key:${svc.secrets.radarrApiKeyFile}" ];
          };
        }
      ]
    ))
  ];
}
