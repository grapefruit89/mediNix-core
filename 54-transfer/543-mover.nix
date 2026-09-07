# ---
# id: "543-mover"
# title: "Ondemand Tier-B→Tier-C Mover (move media to HDD when SSD low)"
# domain: 54
# folder: 54-transfer
# status: active
# complexity: 3
# last_reviewed: 2026-08-13
# links: 
# provides: []
# requires: ["lib/hardening-profiles"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5430 (cold-archive tiering), ADR-5000 (event/timer-driven, no legacy cron)
# skill: medinix-implement-discipline
# note: "No Calendar-Timer. HDD sleeps. systemd.path is the trigger, minFreeGb is the brake."
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.mover;
  svc = config.medinix;

  moverScript = pkgs.writeShellApplication {
    name = "mediNix-mover";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.gawk pkgs.util-linux pkgs.lsof ];
    text = ''
      set -euo pipefail

      STAGING="${cfg.stagingDir}"
      ARCHIVE="${cfg.archiveDir}"
      MIN_FREE_KB=$(( ${toString cfg.minFreeGb} * 1024 * 1024 ))


      # Prevent writing to root SSD if mount fails
      if [ "$(stat -c "%m" "$ARCHIVE" 2>/dev/null || echo "/")" = "/" ]; then
        echo "Mover: ARCHIVE $ARCHIVE is on the root partition! Aborting to prevent SSD fill-up."
        exit 1
      fi

      # Fund 5: Cleanup stale staging files from previous interrupted runs (older than 24h)
      if [ -d "$ARCHIVE/.staging_mover" ]; then
        find "$ARCHIVE/.staging_mover" -type f -mtime +1 -delete
      fi


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

      # 2. Only whitelisted extensions AND >= 50MB, not modified in last 5 minutes (-mmin +5)
      mkdir -p "$ARCHIVE/.staging_mover"
      find "$STAGING" -type f -size +50M -mmin +5 \( ${lib.concatMapStringsSep " -o " (e: "-name '*${e}'") cfg.mediaExtensions} \) -print0 \
        | while IFS= read -r -d $'\0' f; do
          [ -f "$f" ] || continue

          # Target reached check: stop once enough free space on SSD is achieved
          CURRENT_FREE_KB=$(df -Pk "$STAGING" | awk 'NR==2 {print $4}')
          if [ "$CURRENT_FREE_KB" -ge "$MIN_FREE_KB" ]; then
            echo "Mover: reached target free space ($(($CURRENT_FREE_KB/1024)) MB >= $(($MIN_FREE_KB/1024)) MB) — stopping"
            break
          fi

          # Lock check: skip if file is actively open by any process (e.g. SABnzbd download/unrar)
          if lsof -t "$f" >/dev/null 2>&1; then
            echo "Mover: file is currently in use, skipping: $f"
            continue
          fi

          rel="''${f#"$STAGING"/}"
          dest="$ARCHIVE/$rel"

          # Atomic Move Logic:
          # 1. Copy to a collision-free temporary file on the SAME filesystem (HDD)
          # 2. Atomic rename to the final destination so Jellyfin never sees incomplete files
          staging_dest=$(mktemp -p "$ARCHIVE/.staging_mover" "tmp_XXXXXX_$(basename "$f")")
          mkdir -p "$(dirname "$dest")"

          echo "Mover: transferring $rel ..."
          if cp -f "$f" "$staging_dest" && mv -f "$staging_dest" "$dest"; then
            rm -f "$f"
            echo "Mover: successfully moved $rel"
          else
            echo "Mover: ERROR moving $f — preserving source file" >&2
            rm -f "$staging_dest" 2>/dev/null || true
          fi
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


  # Fund 2: Safety backstop timer because PathChanged isn't recursive
  systemd.timers.mediNix-mover-safety = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnUnitInactiveSec = "8h";
      Unit = "mediNix-mover.service";
    };
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
