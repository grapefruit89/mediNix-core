# ---
# id: "536-prowlarr"
# title: "Prowlarr — Indexer Manager (53-acquisition, Service 536)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# logo: https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/prowlarr.svg
# links:
# provides: []
# requires: ["lib/arr-settings", "lib/service-factory", "lib/registry", "lib/hardening-profiles", "lib/memory-policy"]
# adr: ADR-5320, ADR-5050
# ---
# ─────────────────────────────────────────────────────────────────────────────
# ARCHITEKTUR-VORGABE: PROWLARR WIRD NICHT AN DEN VPN-KILLSWITCH GEBUNDEN!
# Prowlarr benötigt direkten WAN-Zugang und läuft bewusst über das Standard-Host-
# Netzwerk (ohne VPN). Der VPN-Killswitch ist ausschließlich für den Payload-
# Downloader (SABnzbd) reserviert.
# ─────────────────────────────────────────────────────────────────────────────
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.prowlarr;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.prowlarr;
  meta = config.medinix.manifest.prowlarr;

  inherit (meta) port uid stateDir;
  inherit (reg) gid;
  mkService = import ../lib/service-factory.nix { inherit lib config; };
  arrSettings = import ../lib/arr-settings.nix { inherit lib; };

  package = if cfg.package != null then cfg.package else pkgs.prowlarr;

  # F2: Forward-auth detection follows resolved exposure (ingress.vhosts or manifest)
  exposedPublic =
    (config.medinix.ingress.vhosts."prowlarr".accessGroup or meta.accessGroup or "none") == "public";
  authMethod =
    if (config.medinix.ingress.auth.mode == "forward-auth" && exposedPublic) then
      "External"
    else
      "Forms";
in
{
  options.medinix.prowlarr = {
    enable = lib.mkEnableOption "Prowlarr Indexer Proxy";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "null";
      description = ''
        Optionales Paket-Override für Prowlarr.
        null = NixOS-Modul-Default aus nixpkgs.
      '';
    };
  };

  config = lib.mkMerge [
    # ── 1. SERVICE-MANIFEST (Top-Level: Immer im Katalog, SSoT) ─────────────
    {
      medinix.manifest.prowlarr = {
        inherit (cfg) enable;
        inherit (reg) num;
        accessGroup = "internal";

        ui = {
          title = "Prowlarr";
          description = "Indexer-Proxy & Integration";
          icon = "prowlarr";
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
          role = "indexer";
          apiVersion = "v1";
        };

        ops = {
          priority = "medium";
          ramBudget = "512M";
          notes = "Indexer-Proxy für Sonarr, Radarr, Lidarr und Readarr.";
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
              message = "[mediNix/536-prowlarr] Manifest-Nummer (${toString meta.num}) stimmt nicht mit lib/registry.nix (${toString reg.num}) überein!";
            }
          ];

          users.groups.media.gid = gid;
        }
        (mkService {
          name = "prowlarr";
          ownsAccount = false; # users.users.prowlarr besitzt die Engine (UPG)
          inherit port;
          inherit uid;
          execStart = "${package}/bin/Prowlarr -nobrowser -data=${stateDir}";
          inherit stateDir;
          profile = "dotnet";
          allowedPeers = [ "sabnzbd" ];
          extraConfig = {
            User = "prowlarr";
            UMask = "0002";
            ReadWritePaths = [ stateDir ];
          };
        })
        {
          systemd.services.prowlarr = {
            after = [ "network.target" ];
            requires = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            onFailure = [ "alert-ntfy@%n.service" ];
            environment = lib.mkMerge [
              (lib.mkIf (svc.secrets.prowlarrApiKeyFile or null != null) {
                PROWLARR_API_KEY_FILE = svc.secrets.prowlarrApiKeyFile;
              })
              (arrSettings.mkProwlarr {
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
                  instanceName = "Prowlarr";
                };
                log.level = "info";
                update.mechanism = "BuiltIn";
              })
            ];
          };

          systemd.sockets.prowlarr = lib.mkIf svc.onDemand.enable {
            wantedBy = [ "sockets.target" ];
            listenStreams = [ "127.0.0.1:${toString port}" ];
            socketConfig.Accept = false;
          };
        }
        {
          systemd.services."prowlarr" = lib.mkIf (svc.secrets.prowlarrApiKeyFile or null != null) {
            serviceConfig.LoadCredentialEncrypted = [ "prowlarr-api-key:${svc.secrets.prowlarrApiKeyFile}" ];
          };
        }
      ]
    ))
  ];
}
