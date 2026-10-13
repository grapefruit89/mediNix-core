# ---
# id: "585-exporters"
# title: "Exporters — Manifest-driven Prometheus Exporters (Observability-Konsument)"
# domain: 58
# folder: 58-observability
# status: active
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

  # Generiere einen systemd-Service pro exportarr-fähigem Dienst
  mkExportarrService =
    name: m:
    let
      exporterPort = 8000 + m.num;
    in
    {
      name = "exportarr-${name}";
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
            User = "media";
            Group = "media";
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
  };
}
