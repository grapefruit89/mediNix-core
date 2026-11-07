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
#   adr: ADR-532, ADR-5050
# provides: []
# requires: ["53-acquisition/arr-settings", "50-core/service-factory", "50-core/registry", "50-core/hardening-profiles", "50-core/memory-policy"]
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
  keySync = import ./arr-key-sync.nix {
    inherit pkgs;
    name = "lidarr";
  };
  registry = (import ../50-core/registry.nix { inherit lib; }).services;
  reg = registry.lidarr;
  meta = config.medinix.manifest.lidarr;

  inherit (meta) port uid stateDir;
  inherit (reg) sharedGid;
  mkService = import ../50-core/service-factory.nix { inherit lib config; };
  arrSettings = import ./arr-settings.nix { inherit lib; };

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
        inherit (cfg) enable;
        inherit (reg) num;
        accessGroup = "internal";

        ui = {
          title = "Lidarr";
          description = "Musik-Verwaltung & Automatisierung";
          icon = "lidarr";
          group = "Acquisition";
        };

        monitoring = {
          inherit (cfg) enable;
          type = "http";
          healthPath = "/api/v1/system/status";
          expectedStatus = 200;
        };

        metrics = {
          inherit (cfg) enable;
          type = "exportarr";
        };

        arr = {
          role = "media-manager";
          category = "music";
          apiVersion = "v1";
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
              message = "[mediNix/535-lidarr] Manifest-Nummer (${toString meta.num}) stimmt nicht mit 50-core/registry.nix (${toString reg.num}) überein!";
            }
          ];

          users.groups.media.gid = sharedGid;
        }
        (mkService {
          name = "lidarr";
          ownsAccount = false; # users.users.lidarr besitzt die Engine (UPG)
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
                log.consoleLevel = "debug";
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
            serviceConfig = {
              LoadCredentialEncrypted = [ "lidarr-api-key:${svc.secrets.lidarrApiKeyFile}" ];
              # Die App ignoriert Env-Overrides fuer ApiKey; der versiegelte
              # Wert wird deshalb vor dem Start in config.xml geschrieben.
              ExecStartPre = [ "${keySync}/bin/arr-api-key-sync-lidarr" ];
            };
          };
        }
      ]
    ))
  ];
}
