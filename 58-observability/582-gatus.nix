# ---
# id: "582-gatus"
# title: "Gatus — Health Dashboard (Manifest-Konsument, Service 582)"
# domain: 58
# folder: 58-observability
# adr: ADR-582
# status: active
# last_reviewed: 2026-10-15
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.gatus;
  svc = config.medinix;
  reg = (import ../lib/registry.nix { inherit lib; }).services.gatus;

  inherit (reg)
    num
    port
    uid
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

  # Gatus-Konfiguration. Bewusst NICHT ueber services.gatus: das Upstream-Modul
  # setzt DynamicUser = true (verletzt die locked_invariants: DynamicUser = false,
  # UID = Port = 5820) und bindet standardmaessig Port 8080 statt 5820.
  gatusConfig = {
    web.port = port;
    metrics = true;
    ui = {
      title = "mediNix Status";
      header = "mediNix Infrastructure Health";
    };
    endpoints = allEndpoints;
  };

  # Unit ueber die Factory: Hardening-Profil + StateDirectory an einer Stelle.
  conn = import ../lib/service-factory.nix { inherit lib config pkgs; };
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

      # Konfiguration deklarativ ablegen; Gatus liest sie ueber GATUS_CONFIG_PATH.
      environment.etc."gatus/config.yaml".source =
        (pkgs.formats.yaml { }).generate "gatus-config.yaml"
          gatusConfig;
    })

    # Nativ statt services.gatus (siehe gatusConfig oben). ownsAccount = false:
    # users.users.gatus, UPG-Group und StateDirectory besitzt die Engine.
    # Die Factory liefert ein ganzes Config-Fragment (systemd.* + medinix.*),
    # deshalb wird sie als eigener Block in mkMerge gemergt, nicht zugewiesen.
    # Hinweis: ICMP-Pruefungen wuerden CAP_NET_RAW brauchen (AmbientCapabilities
    # + CapabilityBoundingSet); die generierten Endpunkte sind HTTP/TCP.
    (lib.mkIf cfg.enable (conn {
      name = "gatus";
      ownsAccount = false;
      inherit uid stateDir;
      execStart = "${pkgs.gatus}/bin/gatus";
      profile = "base";
      extraConfig = {
        Environment = [ "GATUS_CONFIG_PATH=/etc/gatus/config.yaml" ];
      };
    }))
  ];
}
