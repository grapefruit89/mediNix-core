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
# Dienste mit `metrics.enable && metrics.type == "exportarr"`
# einen gehärteten Exportarr-Dienst auf Port 8000 + m.num.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };

  # Aktive Dienste mit Exportarr-Metriken filtern
  exportarrServices = lib.filterAttrs (
    _: m: m.enable && (m.metrics.enable or false) && (m.metrics.type or "none") == "exportarr"
  ) (config.medinix.manifest or { });

  # Identitaet je Exporter: eigener UPG-Account, uid = gid = Port = 8000 + num
  # (ADR-0000: uid == port). Deklariert wird nur die ABSICHT; die Konten leitet
  # die Engine ab (ADR-040/L-046: kein Modul schreibt users.*, waehrend es das
  # Manifest liest).
  unitOf = name: "exportarr-${name}";
  uidOf = m: 8000 + m.num;

  # Generiere einen systemd-Service pro exportarr-fähigem Dienst
  mkExportarrService =
    name: m:
    let
      unit = unitOf name;
      exporterPort = 8000 + m.num;
    in
    {
      name = unit;
      value = {
        description = "Exportarr Prometheus Exporter for ${m.ui.title or name}";
        after = [
          "network-online.target"
          "${name}.service"
        ];
        requires = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        onFailure = [ "alert-ntfy@%n.service" ];
        serviceConfig = lib.mkMerge [
          # network-Profile: Go binary, port binding via CAP_NET_BIND_SERVICE
          profiles.network
          {
            ExecStart = "${pkgs.exportarr}/bin/exportarr ${name} --port ${toString exporterPort} --url http://127.0.0.1:${toString m.port}";
            User = unit;
            Group = unit;
            UMask = "0002";
            Restart = "on-failure";
            RestartSec = "10s";
          }
        ];
      };
    };
in
{
  config = {
    systemd.services = lib.listToAttrs (lib.mapAttrsToList mkExportarrService exportarrServices);

    # ABSICHT (ADR-040): die Engine leitet daraus die Konten ab.
    medinix.exporters = lib.listToAttrs (
      lib.mapAttrsToList (name: m: {
        name = unitOf name;
        value.uid = uidOf m;
      }) exportarrServices
    );

    # Fabrik-Registrierung: der ADR-5050-Guardrail (591) prueft damit User/
    # Group/StateDirectory dieser Units (stateDir = null: stateless).
    medinix.factoryUnits = lib.listToAttrs (
      lib.mapAttrsToList (name: m: {
        name = unitOf name;
        value = {
          uid = uidOf m;
          stateDir = null;
        };
      }) exportarrServices
    );
  };
}
