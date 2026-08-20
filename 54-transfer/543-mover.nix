# ---
# id: "543-mover"
# title: "Ondemand Tier-B→Tier-C Mover (move media to HDD when SSD low)"
# domain: 54
# folder: 54-transfer
# status: active
# complexity: 3
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-5430 (cold-archive tiering), ADR-5000 (event/timer-driven, no legacy cron)
#   skill: medinix-implement-discipline
#   note: "No Calendar-Timer. HDD sleeps. systemd.path is the trigger, minFreeGb is the brake."
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.mover;
  svc = config.grapefruitMedia;

  moverScript = pkgs.writeShellApplication {
    name = "mediNix-mover";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.gawk pkgs.util-linux pkgs.lsof ];
    text = ''
      set -euo pipefail

      STAGING="${cfg.stagingDir}"
      ARCHIVE="${cfg.archiveDir}"
      MIN_FREE_KB=$(( ${toString cfg.minFreeGb} * 1024 * 1024 ))

      # 1. Fill level check on Staging (Tier-B/SSD)
      if [ ! -d "$STAGING" ]; then
        echo "Mover: stagingDir $STAGING not found — skip"
        exit 0
      fi
      FREE_KB=$(df -Pk "$STAGING" | awk 'NR==2 {print $4}')
      if [ "$FREE_KB" -ge "$MIN_FREE_KB" ]; then
        echo "Mover: enough free space ($(($FREE_KB/1024)) MB >= $(($MIN_FREE_KB/1024)) MB) — nothing to do"
        exit 0
      fi
      echo "Mover: SSD is low ($(($FREE_KB/1024)) MB free) → moving media to $ARCHIVE"

      # 2. Only whitelisted extensions AND >= 50MB, recursive, correctly bracketed
      mkdir -p "$ARCHIVE"
      find "$STAGING" -type f -size +50M \( ${lib.concatMapStringsSep " -o " (e: "-name '*${e}'") cfg.mediaExtensions} \) \
        | while read -r f; do
          rel="''${f#"$STAGING"/}"
          dest="$ARCHIVE/$rel"
          mkdir -p "$(dirname "$dest")"
          mv -f "$f" "$dest"
        done

      echo "Mover done"
    '';
  };
in
lib.mkIf (svc.enable && cfg.enable && cfg.mode != "off") {
  # systemd.services with StartLimit + Hardening
  systemd.services.mediNix-mover = {
    description = "Ondemand Tier-B→Tier-C Mover (move media to HDD when SSD low)";
    # StartLimit belongs in [Unit] (= unitConfig), not in [Service] (serviceConfig).
    # Limits real service starts if staging is noisy (not just Log-IO).
    unitConfig = {
      RequiresMountsFor = [ cfg.stagingDir cfg.archiveDir ];
      StartLimitBurst = 3;
      StartLimitIntervalSec = "60";
    };
    serviceConfig = lib.mkMerge [
      (import ../lib/hardening-profiles.nix { inherit lib; }).script
      {
        Type = "oneshot";
        User = "media";
        Group = "media";
        UMask = "002";
      
      RuntimeDirectory = "medinix-mover";
        ReadWritePaths = [ cfg.stagingDir cfg.archiveDir ];
        RateLimitBurst = 5;
        RateLimitIntervalSec = "30s";
      }
    ];
    script = "${lib.getExe moverScript}";
  };

  # systemd.path as a trigger: fires on activity under stagingDir, not by clock.
  systemd.paths.mediNix-mover = {
    wantedBy = [ "paths.target" ];
    pathConfig = {
      PathChanged = cfg.stagingDir;
      # DirectoryNotEmpty removed to prevent trigger loops
    };
  };
}
