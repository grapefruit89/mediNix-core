# ---
# id: "535-lidarr"
# title: "Lidarr — Music Download Manager (53-acquisition, Service 535)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# logo: https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/lidarr.svg
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
  cfg = config.medinix.lidarr;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.lidarr;
  meta = config.medinix.manifest.lidarr;

  inherit (meta) port uid stateDir;
  inherit (reg) gid;
  mkService = import ../lib/service-factory.nix { inherit lib config; };
  arrSettings = import ../lib/arr-settings.nix { inherit lib; };

  package = if cfg.package != null then cfg.package else pkgs.lidarr;
in
{
  options.medinix.lidarr = {
    enable = lib.mkEnableOption "Lidarr Music Download Manager";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "null";
      description = ''
        Optionales Paket-Override für Lidarr.
        null = NixOS-Modul-Default aus nixpkgs.
      '';
    };
  };

  config = lib.mkMerge [
    # ── 1. SERVICE-MANIFEST (Top-Level: Immer im Katalog, SSoT) ─────────────
    {
      medinix.manifest.lidarr = {
        enable = cfg.enable;
        num = reg.num;
        accessGroup = "internal";

        ui = {
          title = "Lidarr";
          description = "Musik-Verwaltung & Automatisierung";
          icon = "lidarr";
          group = "Acquisition";
        };

        monitoring = {
          enable = cfg.enable;
          type = "http";
          healthPath = "/api/v1/system/status";
          expectedStatus = 200;
        };

        metrics = {
          enable = cfg.enable;
          type = "exportarr";
        };

        ops = {
          priority = "medium";
          ramBudget = "1G";
          notes = "Arr-Musik-Management mit Prowlarr- und SABnzbd-Kopplung.";
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
              message = "[mediNix/535-lidarr] Manifest-Nummer (${toString meta.num}) stimmt nicht mit lib/registry.nix (${toString reg.num}) überein!";
            }
          ];

          users.groups.media.gid = gid;
        }
        (mkService {
          name = "lidarr";
          inherit port;
          inherit uid;
          execStart = "${package}/bin/Lidarr -nobrowser -data=${stateDir}";
          inherit stateDir;
          profile = "dotnet";
          offloadMediaCover = true;
          allowedPeers = [
            "sabnzbd"
            "prowlarr"
          ];
          extraConfig = {
            User = "lidarr";
            UMask = "0002";
            ReadWritePaths = [
              stateDir
              config.medinix.storage.mediaRoot
            ];
          };
        })
        {
          systemd.services.lidarr = {
            after = [
              "network.target"
              "prowlarr.service"
            ];
            requires = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            onFailure = [ "alert-ntfy@%n.service" ];
            environment = lib.mkMerge [
              (lib.mkIf (svc.secrets.lidarrApiKeyFile or null != null) {
                LIDARR_API_KEY_FILE = svc.secrets.lidarrApiKeyFile;
              })
              (arrSettings.mkLidarr {
                server = {
                  inherit port;
                  bindAddress = "127.0.0.1";
                  urlBase = "";
                };
                auth = {
                  method = "Forms";
                  required = "Enabled";
                };
                app = {
                  theme = "dark";
                  instanceName = "Lidarr";
                };
                log.level = "info";
                update.mechanism = "BuiltIn";
              })
            ];
          };

          systemd.sockets.lidarr = lib.mkIf svc.onDemand.enable {
            wantedBy = [ "sockets.target" ];
            listenStreams = [ "127.0.0.1:${toString port}" ];
            socketConfig.Accept = false;
          };
        }
        {
          systemd.services."lidarr" = lib.mkIf (svc.secrets.lidarrApiKeyFile != null) {
            serviceConfig.LoadCredentialEncrypted = [ "lidarr-api-key:${svc.secrets.lidarrApiKeyFile}" ];
          };
        }
      ]
    ))
  ];
}
