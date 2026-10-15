# ---
# id: "561-seerr"
# title: "Seerr — Request Management"
# domain: 56
# last_reviewed: 2026-10-14
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
  meta = config.medinix.manifest.seerr;

  inherit (meta) port stateDir;
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
        inherit (cfg) enable;
        num = 561;
        accessGroup = "public";

        ui = {
          title = "Seerr";
          description = "Medien-Anfragen & Entdeckung";
          icon = "seerr";
          group = "Media";
        };

        monitoring = {
          inherit (cfg) enable;
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
      systemd.tmpfiles.rules = [
        "d '${stateDir}' 0750 root media -"
      ];

      systemd.services.seerr = {
        after = [
          "network-online.target"
          "jellyfin.service"
        ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        onFailure = [ "alert-ntfy@%n.service" ];
        serviceConfig = lib.mkMerge [
          profiles.nodejs
          memoryPolicy.seerr
          {
            ExecStart = lib.getExe seerrPkg;
            WorkingDirectory = stateDir;
            ReadWritePaths = [ stateDir ];
            ExecStartPre = [
              (pkgs.writeShellScript "seerr-wal-enable" ''
                for db in "${stateDir}/db/db.sqlite3" "${stateDir}/db.sqlite3"; do
                  if [ -f "$db" ]; then
                    ${pkgs.sqlite}/bin/sqlite3 "$db" "PRAGMA journal_mode=WAL;" >/dev/null 2>&1 || true
                  fi
                done
              '')
            ];
          }
          (lib.mkIf (cfg.envFile != null) {
            EnvironmentFile = cfg.envFile;
          })
        ];
        environment = {
          PORT = toString port;
          HOST = "127.0.0.1";
        };
      };
    })
  ];
}
