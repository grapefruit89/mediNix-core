# ---
# id: "587-disk-health"
# title: "SMART Disk Health Monitoring (smartd with Standby Preservation)"
# domain: 58
# folder: 58-observability
# status: active
# complexity: 2
# adr: ADR-5870
# ---
# Monitors physical drive health (reallocated/pending sectors, temperatures, drive failures)
# while strictly preserving HDD spindown using smartd's '-n standby,q' flag.
# Alerts are dispatched directly to mediNix's internal ntfy instance (Domain 581).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.diskHealth;
  svc = config.medinix;
  ntfyPort = config.medinix.ntfy.port or 5810;

  # Alert script executed by smartd on failure (-M exec ...)
  smartdAlertScript = pkgs.writeShellScript "smartd-ntfy-alert" ''
    set -eu
    DEV="''${SMARTD_DEVICESTRING:-unknown device}"
    MSG="''${SMARTD_MESSAGE:-SMART health warning}"
    HOST="$(hostname 2>/dev/null || echo "mediNix")"
    ALERT_TEXT="SMART Warning on $HOST ($DEV): $MSG"

    echo "$ALERT_TEXT" >&2

    if [ "${if cfg.notifyNtfy then "1" else "0"}" = "1" ]; then
      ${pkgs.curl}/bin/curl -s -d "$ALERT_TEXT" \
        -H "Title: SMART Disk Warning" \
        -H "Priority: urgent" \
        -H "Tags: warning,harddrive" \
        "http://127.0.0.1:${toString ntfyPort}/alerts" || true
    fi
  '';

  standbyOpt = if cfg.spindownPreservation then "-n standby,q" else "";
  alertOpt = "-m root -M exec ${smartdAlertScript}";
  smartdOpts = lib.concatStringsSep " " (
    lib.filter (s: s != "") [
      "-a"
      "-o on"
      "-S on"
      standbyOpt
      alertOpt
    ]
  );
in
lib.mkIf (svc.enable && cfg.enable) {
  services.smartd = {
    enable = true;
    autodetect = cfg.devices == [ "DEVICESCAN" ];
    devices = map (dev: {
      device = dev;
      options = smartdOpts;
    }) cfg.devices;
    notifications = {
      mail.enable = false;
      wall.enable = false;
    };
  };
}
