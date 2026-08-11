# ---
# id: "572-recyclarr"
# title: "Recyclarr — TRaSH-Guides Sync (Timer-driven, per-instance)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5043
#   skill: nixos-context7-gate
#   repo-harvest: recyclarr/recyclarr (.NET 10, recyclarr.yml, `recyclarr sync`)
# context7:
#   - query: "systemd.timers OnCalendar example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "timerConfig.OnCalendar for scheduled sync"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.maintenance.recyclarr;
  svc = config.grapefruitMedia;
  stateDir = "/var/lib/recyclarr-${toString cfg.port}";
in lib.mkIf cfg.enable {
  users.users.recyclarr = {
    uid = cfg.port;  # isomorph: 560 × 10 = 5600
    group = "media";
    extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = 5000;

  # Timer: schedule aus Config (Default weekly)
  systemd.timers.recyclarr = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = cfg.schedule;  # z.B. "daily" oder "*-*-* 04:00:00"
      Persistent = true;
    };
  };

  systemd.services.recyclarr = {
    description = "Recyclarr TRaSH-Guides sync";
    after = [ "network-online.target" ] ++ lib.optional svc.services.sonarr.enable "sonarr-5320.service"
      ++ lib.optional svc.services.radarr.enable "radarr-5330.service";
    serviceConfig = {
      Type = "oneshot";
      User = "recyclarr";
      Group = "media";
      UMask = "002";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      StateDirectory = "recyclarr-${toString cfg.port}";
      ReadWritePaths = [ stateDir ];
      # Harvester #911: multi-instance split bug → sync each instance separately
      # via -i flag in script loop (nicht bare `recyclarr sync`)
    };
    environment = {
      RECYCLARR_CONFIG = "${stateDir}/recyclarr.yml";
    };
    script = ''
      set -euo pipefail
      CONFIG="${stateDir}/recyclarr.yml"
      if [ ! -f "$CONFIG" ]; then
        echo "No recyclarr.yml found at $CONFIG — skipping"
        exit 0
      fi
      # Workaround #911: sync each instance individually
      for inst in $(${pkgs.recyclarr}/bin/recyclarr config list 2>/dev/null || echo ""); do
        ${pkgs.recyclarr}/bin/recyclarr sync -i "$inst" || true
      done
    '';
  };
}
