# ---
# id: "587-disk-health"
# title: "SMART Physical Drive Health & Failure Alerts (smartd)"
# domain: 58
# folder: 58-observability
# status: active
# complexity: 2
# last_reviewed: 2026-11-26
# links:
#   adr: ADR-587
# requires: ["50-core/hardening-profiles", "50-core/registry"]
# ---
# Monitors physical drive health (smartd with '-n standby,q' to avoid wakeups)
# and sends urgent push notifications via ntfy on impending drive failures.
# (Spindown timeout and standby power-event logging reside in 570-storage.nix).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.diskHealth;
  svc = config.medinix;
  ntfyPort = (import ../50-core/registry.nix { inherit lib; }).services.ntfy.port;

  # Alert script executed by smartd on failure (-M exec ...)
  smartdAlertScript = pkgs.writeShellScript "smartd-ntfy-alert" ''
    set -eu
    DEV="''${SMARTD_DEVICESTRING:-unknown device}"
    MSG="''${SMARTD_MESSAGE:-SMART health warning}"
    HOST="$(hostname 2>/dev/null || echo "mediNix")"
    ALERT_TEXT="SMART Warning on $HOST ($DEV): $MSG"

    echo "$ALERT_TEXT" >&2

    ${lib.optionalString cfg.notifyNtfy ''
      ${pkgs.curl}/bin/curl -s -d "$ALERT_TEXT" \
        -H "Title: SMART Disk Warning" \
        -H "Priority: urgent" \
        -H "Tags: warning,harddrive" \
        "http://127.0.0.1:${toString ntfyPort}/alerts" || true
    ''}
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
