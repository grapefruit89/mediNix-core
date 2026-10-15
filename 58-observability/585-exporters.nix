# ---
# id: "585-exporters"
# title: "Exporters — Manifest-driven Prometheus Exporters (Observability-Konsument)"
# domain: 58
# folder: 58-observability
# status: active
# last_reviewed: 2026-10-16
# ---
# Reiner Manifest-Konsument: Kennt keinen Dienst namentlich.
# Iteriert über config.medinix.manifest und generiert für alle
# Dienste mit `metrics.enable && metrics.type == "exportarr"` einen gehärteten
# Exportarr-Dienst.
#
# Identitaet (ADR-0000 §4): eigener UPG-Account je Exporter (Namen = Unit).
# uid = gid = Port (exporterBase + num) — dieselbe "Port == UID"-Idee wie im
# Dezimalrahmen, ohne einen Registry-Eintrag zu erfinden. KEIN geteiltes "media"
# mehr. Die Units stehen in `medinix.factoryUnits` -> Guardrail 591 prueft sie.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };

  # Exporter-Port-/UID-Basis (benannte Konstante statt Streuzahl).
  exporterBase = 8000;

  exportarrServices = lib.filterAttrs (
    _: m: m.enable && (m.metrics.enable or false) && (m.metrics.type or "none") == "exportarr"
  ) (config.medinix.manifest or { });

  # Ein Exporter = ein Fragment { systemd.services, users, medinix.factoryUnits }.
  mk =
    name: m:
    let
      unit = "exportarr-${name}";
      uid = exporterBase + m.num; # uid = gid = port
    in
    {
      systemd.services."${unit}" = {
        description = "Exportarr Prometheus Exporter for ${m.ui.title or name}";
        after = [
          "network-online.target"
          "${name}.service"
        ];
        requires = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        onFailure = [ "alert-ntfy@%n.service" ];
        serviceConfig = lib.mkMerge [
          # network-Profil: Go-Binary, Port-Bindung via CAP_NET_BIND_SERVICE
          profiles.network
          {
            ExecStart = "${pkgs.exportarr}/bin/exportarr ${name} --port ${toString uid} --url http://127.0.0.1:${toString m.port}";
            User = unit;
            Group = unit;
            UMask = "0002";
            Restart = "on-failure";
            RestartSec = "10s";
          }
        ];
      };
      users.groups."${unit}".gid = uid;
      users.users."${unit}" = {
        uid = uid;
        group = unit;
        isSystemUser = true;
      };
      medinix.factoryUnits."${unit}" = {
        uid = uid;
        stateDir = null; # stateless -> kein StateDirectory (591 prueft nur bei != null)
      };
    };
in
{
  config = lib.mkMerge (lib.mapAttrsToList mk exportarrServices);
}
