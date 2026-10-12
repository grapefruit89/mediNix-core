# ---
# id: "555-seerr"
# title: "Seerr — Request Management"
# domain: 55
# last_reviewed: 2026-09-02
# sprite: 50-core/icons.svg#seerr
# provides: ["seerr"]
# adr: ADR-5610
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.seerr;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.seerr;
  meta = config.medinix.manifest.seerr;

  inherit (meta) port uid stateDir;
  inherit (reg) gid;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  memoryPolicy = import ../lib/memory-policy.nix { inherit lib; };
  seerrPkg =
    if cfg.package != null then cfg.package else pkgs.seerr or (pkgs.jellyseerr or pkgs.overseerr);
in
{
  options.medinix.seerr = {
    enable = lib.mkEnableOption "Seerr request manager (https://seerr.dev)";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "null";
      description = ''
        Optionales Paket-Override für Seerr.
        null = NixOS-Modul-Default aus nixpkgs.
      '';
    };

    envFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optionale EnvironmentFile für Seerr-Laufzeitvariablen.";
    };
  };

  config = lib.mkMerge [
    # ── 1. SERVICE-MANIFEST (Top-Level: Immer im Katalog, SSoT) ─────────────
    {
      medinix.manifest.seerr = {
        enable = cfg.enable;
        num = reg.num;
        accessGroup = "public";

        ui = {
          title = "Seerr";
          description = "Medien-Anfragen & Entdeckung";
          icon = "seerr";
          group = "Media";
        };

        monitoring = {
          enable = cfg.enable;
          type = "http";
          healthPath = "/api/v1/status";
          expectedStatus = 200;
        };

        ops = {
          priority = "medium";
          ramBudget = "1G";
          notes = "Request Manager (Jellyseerr/Overseerr).";
        };
      };
    }

    # ── 2. RUNTIME & SYSTEMD (Nur aktiv wenn cfg.enable = true) ─────────────
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = meta.num == reg.num;
          message = "[mediNix/555-seerr] Manifest-Nummer (${toString meta.num}) stimmt nicht mit lib/registry.nix (${toString reg.num}) überein!";
        }
      ];

      users.users.seerr = {
        inherit uid;
        group = "media";
        extraGroups = [ "media" ];
        home = stateDir;
        isSystemUser = true;
      };
      users.groups.media.gid = gid;

      systemd.services.seerr = {
        after = [
          "network.target"
          "jellyfin.service"
        ];
        requires = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        onFailure = [ "alert-ntfy@%n.service" ];
        serviceConfig = lib.mkMerge [
          profiles.nodejs
          memoryPolicy.seerr
          {
            ExecStart = lib.getExe seerrPkg;
            User = "seerr";
            Group = "media";
            UMask = "0002";
            StateDirectory = "seerr-${toString port}";
            ReadWritePaths = [ stateDir ];
          }
          (lib.mkIf (cfg.envFile != null) {
            EnvironmentFile = cfg.envFile;
          })
          (lib.mkIf (svc.secrets.seerrApiKeyFile or null != null) {
            LoadCredentialEncrypted = [ "seerr-api-key:${svc.secrets.seerrApiKeyFile}" ];
          })
        ];
        environment = {
          PORT = toString port;
          HOST = "127.0.0.1";
        };
      };

      medinix.ingress.vhosts."seerr" = {
        accessGroup = meta.accessGroup;
      };
    })
  ];
}
