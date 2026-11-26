# ---
# id: "587-disk-health"
# title: "SMART Disk Health, Spindown Timeout & Power-Event Logging"
# domain: 58
# folder: 58-observability
# status: active
# complexity: 2
# last_reviewed: 2026-11-26
# links:
#   adr: ADR-587
# requires: ["50-core/hardening-profiles", "50-core/registry"]
# ---
# Monitors physical drive health (smartd with '-n standby,q'), applies ATA
# spindown timeouts (default 120m -> hdparm -S 244), and logs standby/active
# power transitions silently to journald (SYSLOG_IDENTIFIER=medinix-disk-power).
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
  profiles = import ../50-core/hardening-profiles.nix { inherit lib; };

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

  # ATA spindown encoding (hdparm -S): 1..240 = N*5s (<=20m), 241..251 = (N-240)*30m (120m => 244)
  spindownArg =
    let
      m = cfg.spindownDelayMinutes;
    in
    if m == 0 then
      0
    else if m <= 20 then
      m * 12
    else
      let
        steps = (m + 29) / 30;
      in
      240 + (if steps > 11 then 11 else steps);

  discoverDisksSnippet = ''
    disks=()
    ${
      if cfg.devices == [ "DEVICESCAN" ] then
        ''
          for sysdev in /sys/block/sd*; do
            [ -e "$sysdev/queue/rotational" ] || continue
            [ "$(cat "$sysdev/queue/rotational" 2>/dev/null || echo 0)" = "1" ] || continue
            disks+=("/dev/''${sysdev##*/}")
          done
        ''
      else
        ''
          raw_devices=(${lib.escapeShellArgs cfg.devices})
          for d in "''${raw_devices[@]}"; do
            [ -b "$d" ] || continue
            real="$(readlink -f "$d" 2>/dev/null || true)"
            [ -b "$real" ] || continue
            rot="$(cat "/sys/block/''${real##*/}/queue/rotational" 2>/dev/null || echo 1)"
            [ "$rot" = "1" ] || continue
            disks+=("$d")
          done
        ''
    }
  '';

  spindownScript = pkgs.writeShellApplication {
    name = "mediNix-disk-spindown";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.hdparm
    ];
    text = ''
      set -euo pipefail
      ${discoverDisksSnippet}
      for disk in "''${disks[@]}"; do
        real="$(readlink -f "$disk" 2>/dev/null || echo "$disk")"
        hdparm -S ${toString spindownArg} "$real" >/dev/null 2>&1 || true
      done
    '';
  };

  powerLogScript = pkgs.writeShellApplication {
    name = "mediNix-disk-power";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.hdparm
    ];
    text = ''
      set -euo pipefail
      STATE_DIR="/run/medinix-disk-power"
      mkdir -p "$STATE_DIR"
      ${discoverDisksSnippet}
      now="$(date +%s)"

      for disk in "''${disks[@]}"; do
        real="$(readlink -f "$disk" 2>/dev/null || echo "$disk")"
        state_file="$STATE_DIR/''${real##*/}.state"

        out="$(hdparm -C "$real" 2>/dev/null || true)"
        case "$out" in
          *active/idle*) cur="ACTIVE" ;;
          *standby*|*sleeping*) cur="STANDBY" ;;
          *) continue ;;
        esac

        if [ -r "$state_file" ]; then
          read -r prev prev_ts < "$state_file" || { prev=""; prev_ts="$now"; }
          if [ "$prev" = "STANDBY" ] && [ "$cur" = "ACTIVE" ]; then
            elapsed=$(( now > prev_ts ? now - prev_ts : 0 ))
            printf '[SPIN-UP] %s woke up after %d hours %d minutes in standby\n' \
              "$disk" "$(( elapsed / 3600 ))" "$(( (elapsed % 3600) / 60 ))"
            printf '%s %s\n' "$cur" "$now" > "$state_file"
          elif [ "$prev" = "ACTIVE" ] && [ "$cur" = "STANDBY" ]; then
            elapsed=$(( now > prev_ts ? now - prev_ts : 0 ))
            printf '[SPINDOWN] %s entered standby after %d hours %d minutes active runtime\n' \
              "$disk" "$(( elapsed / 3600 ))" "$(( (elapsed % 3600) / 60 ))"
            printf '%s %s\n' "$cur" "$now" > "$state_file"
          fi
        else
          printf '%s %s\n' "$cur" "$now" > "$state_file"
        fi
      done
    '';
  };

  diskUnitConfig = profiles.script // {
    Type = "oneshot";
    User = "root";
    Group = "root";
    PrivateDevices = false;
    PrivateUsers = false;
    CapabilityBoundingSet = [
      "CAP_SYS_RAWIO"
      "CAP_SYS_ADMIN"
    ];
  };
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

  systemd.services.medinix-disk-spindown = lib.mkIf (cfg.spindownDelayMinutes > 0) {
    description = "Configure ATA HDD spindown delay (${toString cfg.spindownDelayMinutes}m -> hdparm -S ${toString spindownArg})";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = diskUnitConfig // {
      RemainAfterExit = true;
    };
    script = "${lib.getExe spindownScript}";
  };

  systemd.services.medinix-disk-power = lib.mkIf cfg.powerLogging {
    description = "Silent HDD standby/spin-up power transition logger (hdparm -C)";
    serviceConfig = diskUnitConfig // {
      SyslogIdentifier = "medinix-disk-power";
      RuntimeDirectory = "medinix-disk-power";
      RuntimeDirectoryPreserve = "yes";
    };
    script = "${lib.getExe powerLogScript}";
  };

  systemd.timers.medinix-disk-power = lib.mkIf cfg.powerLogging {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = cfg.powerCheckInterval;
      OnUnitActiveSec = cfg.powerCheckInterval;
      Unit = "medinix-disk-power.service";
    };
  };
}
