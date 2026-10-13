# ---
# id: "532-sonarr"
# title: "Sonarr — Series Management (53-acquisition, Service 532)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# logo: https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/sonarr.svg
# links:
# provides: []
# requires: ["lib/arr-settings", "lib/service-factory", "lib/registry", "lib/hardening-profiles", "lib/memory-policy"]
# adr: ADR-5320, ADR-5050
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.sonarr;
  svc = config.medinix;
  meta = config.medinix.manifest.sonarr;

  inherit (meta) port uid stateDir;
  mkService = import ../lib/service-factory.nix { inherit lib config; };
  arrSettings = import ../lib/arr-settings.nix { inherit lib; };

  package = if cfg.package != null then cfg.package else pkgs.sonarr;

  # F2: Forward-auth detection follows resolved exposure (ingress.vhosts or manifest)
  exposedPublic =
    (config.medinix.ingress.vhosts."sonarr".accessGroup or meta.accessGroup or "none") == "public";
  authMethod =
    if (config.medinix.ingress.auth.mode == "forward-auth" && exposedPublic) then
      "External"
    else
      "Forms";
in
{
  options.medinix.sonarr = {
    enable = lib.mkEnableOption "Sonarr TV Series Manager";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "null";
      description = ''
        Optionales Paket-Override für Sonarr.
        null = NixOS-Modul-Default aus nixpkgs.
      '';
    };

    rootFolder = lib.mkOption {
      type = lib.types.str;
      default = svc.storage.mediaRoot + "/series";
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
      medinix.manifest.sonarr = {
        inherit (cfg) enable;
        num = 532;
        accessGroup = "internal";

        ui = {
          title = "Sonarr";
          description = "Serien-Verwaltung & Automatisierung";
          icon = "sonarr";
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
          category = "tv";
        };

        ops = {
          priority = "medium";
          ramBudget = "1.5G";
          notes = "Arr-Serien-Management mit Prowlarr- und SABnzbd-Kopplung.";
        };
      };
    }

    # ── 2. RUNTIME & SYSTEMD (Nur aktiv wenn cfg.enable = true) ─────────────
    (lib.mkIf cfg.enable (
      lib.mkMerge [
        (mkService {
          name = "sonarr";
          inherit port;
          inherit uid;
          execStart = "${package}/bin/Sonarr -nobrowser -data=${stateDir}";
          inherit stateDir;
          profile = "dotnet";
          offloadMediaCover = true;
          allowedPeers = [
            "sabnzbd"
            "prowlarr"
          ];
          extraConfig = {
            User = "sonarr";
            UMask = "0002";
            ReadWritePaths = [
              stateDir
              config.medinix.storage.mediaRoot
            ];
          };
        })
        {
          systemd.services.sonarr = {
            after = [
              "network.target"
              "prowlarr.service"
            ];
            requires = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            onFailure = [ "alert-ntfy@%n.service" ];
            environment = lib.mkMerge [
              (lib.mkIf (svc.secrets.sonarrApiKeyFile or null != null) {
                SONARR_API_KEY_FILE = svc.secrets.sonarrApiKeyFile;
              })
              (arrSettings.mkSonarr {
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
                  instanceName = "Sonarr";
                };
                log.level = "info";
                update.mechanism = "BuiltIn";
              })
            ];
          };

          systemd.sockets.sonarr = lib.mkIf svc.onDemand.enable {
            wantedBy = [ "sockets.target" ];
            listenStreams = [ "127.0.0.1:${toString port}" ];
            socketConfig.Accept = false;
          };
        }
        {
          systemd.services."sonarr" = lib.mkIf (svc.secrets.sonarrApiKeyFile != null) {
            serviceConfig.LoadCredentialEncrypted = [ "sonarr-api-key:${svc.secrets.sonarrApiKeyFile}" ];
          };
        }
      ]
    ))
  ];
}
