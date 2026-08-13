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
#   note: "Kein Calendar-Timer. HDD schläft. systemd.path ist Klingel, minFreeGb ist Bremse."
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.mover;
  svc = config.grapefruitMedia;

  moverScript = pkgs.writeShellApplication {
    name = "mediNix-mover";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.gawk ];
    text = ''
      set -euo pipefail

      STAGING="${cfg.stagingDir}"
      ARCHIVE="${cfg.archiveDir}"
      MIN_FREE_KB=$(( ${toString cfg.minFreeGb} * 1024 * 1024 ))

      # 1. Füllstand-Check auf Staging (Tier-B/SSD)
      if [ ! -d "$STAGING" ]; then
        echo "Mover: stagingDir $STAGING nicht vorhanden — skip"
        exit 0
      fi
      FREE_KB=$(df -Pk "$STAGING" | awk 'NR==2 {print $4}')
      if [ "$FREE_KB" -ge "$MIN_FREE_KB" ]; then
        echo "Mover: frei genug ($(($FREE_KB/1024)) MB >= $(($MIN_FREE_KB/1024)) MB) — nichts zu tun"
        exit 0
      fi
      echo "Mover: SSD knapp ($(($FREE_KB/1024)) MB frei) → verschiebe Media nach $ARCHIVE"

      # 2. Nur Whitelist-Extensions UND >= 50MB, rekursiv, korrekt geklammert
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
  # systemd.services mit StartLimit + Hardening
  systemd.services.mediNix-mover = {
    description = "Ondemand Tier-B→Tier-C Mover (move media to HDD when SSD low)";
    serviceConfig = lib.mkMerge [
      (import ../lib/hardening-profiles.nix { inherit lib; }).script
      {
        Type = "oneshot";
        StartLimitBurst = 3;
        StartLimitIntervalSec = 60;
        User = "media";
        Group = "media";
        UMask = "002";
        ReadWritePaths = [ cfg.stagingDir cfg.archiveDir ];
        RateLimitBurst = 5;
        RateLimitIntervalSec = "30s";
      }
    ];
    script = "${lib.getExe moverScript}";
  };

  # systemd.path als Klingel: feuert bei Aktivität unter stagingDir, nicht nach Uhr.
  systemd.paths.mediNix-mover = {
    wantedBy = [ "paths.target" ];
    pathConfig = {
      PathChanged = cfg.stagingDir;
      DirectoryNotEmpty = cfg.stagingDir;
    };
  };
}
