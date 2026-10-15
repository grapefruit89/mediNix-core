# ---
# id: "582-gatus"
# title: "Gatus — Health Dashboard (Manifest-Konsument, Service 582)"
# domain: 58
# folder: 58-observability
# adr: ADR-582
# status: active
# ---
{
  config,
  lib,
  ...
}:

let
  cfg = config.medinix.gatus;
  svc = config.medinix;
  reg = (import ../lib/registry.nix { inherit lib; }).services.gatus;

  inherit (reg)
    num
    port
    gid
    stateDir
    ;

  # Aktive und überwachbare Dienste aus dem Manifest filtern
  activeServices = lib.filterAttrs (
    _: m: m.enable && m.monitoring.enable && m.monitoring.type != "none"
  ) config.medinix.manifest;

  # 1. HTTP-Endpunkte generieren
  httpEndpoints = lib.mapAttrsToList (_: m: {
    name = m.ui.title;
    group = m.ui.group;
    url = "http://127.0.0.1:${toString m.port}${m.monitoring.healthPath}";
    interval = "30s";
    conditions = [
      "[STATUS] == ${toString m.monitoring.expectedStatus}"
    ];
    alerts = lib.optional (svc.ntfy.enable or false) {
      type = "ntfy";
    };
  }) (lib.filterAttrs (_: m: m.monitoring.type == "http") activeServices);

  # 2. TCP-Socket-Pings generieren
  tcpEndpoints = lib.mapAttrsToList (_: m: {
    name = m.ui.title;
    group = m.ui.group;
    url = "tcp://127.0.0.1:${toString m.port}";
    interval = "30s";
    conditions = [
      "[CONNECTED] == true"
    ];
    alerts = lib.optional (svc.ntfy.enable or false) {
      type = "ntfy";
    };
  }) (lib.filterAttrs (_: m: m.monitoring.type == "tcp") activeServices);

  allEndpoints = httpEndpoints ++ tcpEndpoints;
in
{
  options.medinix.gatus = {
    enable = lib.mkEnableOption "Gatus Health-Monitoring Dashboard";
  };

  config = lib.mkMerge [
    # ── 1. Eigener Manifest-Eintrag (Gatus überwacht sich selbst nicht rekursiv)
    {
      medinix.manifest.gatus = {
        inherit (cfg) enable;
        inherit num;
        accessGroup = "internal";
        extraGroups = [ "media" ];

        ui = {
          title = "Gatus";
          description = "Service Health & Uptime Dashboard";
          icon = "gatus";
          group = "Observability";
        };

        monitoring = {
          enable = false; # Selbstreferenzielle Prüfung vermeiden
          type = "none";
        };

        ops = {
          priority = "high";
          ramBudget = "128M";
          notes = "Zentraler Health-Monitor. Reines Go-Binary.";
        };
      };
    }

    # ── 2. Laufzeit-Konfiguration ──────────────────────────────────────────
    (lib.mkIf cfg.enable {
      users.groups.media.gid = gid;
      systemd.tmpfiles.rules = [
        "d '${stateDir}' 0755 gatus media -"
      ];

      # Natives NixOS Gatus-Service-Setup
      services.gatus = {
        enable = true;
        settings = {
          metrics = true;
          ui = {
            title = "mediNix Status";
            header = "mediNix Infrastructure Health";
          };
          endpoints = allEndpoints;
        };
      };

      systemd.services.gatus = {
        serviceConfig = {
          User = "gatus";
          Group = "media";
          StateDirectory = "gatus-${toString port}";
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          Environment = [ "PORT=${toString port}" ];
        };
      };
    })
  ];
}
