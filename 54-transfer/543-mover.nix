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
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.mover;
  svc = config.medinix;

  moverScript = pkgs.writeShellApplication {
    name = "mediNix-mover";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.util-linux
      pkgs.lsof
    ];
    text = ''
      set -euo pipefail

      STAGING="${cfg.stagingDir}"
      ARCHIVE="${cfg.archiveDir}"
      MIN_FREE_KB=$(( ${toString cfg.minFreeGb} * 1024 * 1024 ))


      # Validate staging and archive paths
      if [ ! -d "$STAGING" ]; then
        echo "Mover: stagingDir $STAGING not found — skip"
        exit 0
      fi
      if [ ! -d "$ARCHIVE" ]; then
        echo "Mover: archiveDir $ARCHIVE not found — aborting"
        exit 1
      fi
      if [ "$STAGING" = "$ARCHIVE" ]; then
        echo "Mover: STAGING and ARCHIVE are identical ($STAGING) — aborting to prevent self-moves."
        exit 1
      fi

      # Prevent writing to root SSD if mount fails
      if [ "$(stat -c "%m" "$ARCHIVE" 2>/dev/null || echo "/")" = "/" ]; then
        echo "Mover: ARCHIVE $ARCHIVE is on the root partition! Aborting to prevent SSD fill-up."
        exit 1
      fi

      # Concurrency protection: prevent overlapping mover runs (manual, timer, or path trigger)
      LOCK_FILE="/run/medinix-mover/mover.lock"
      exec 200>"$LOCK_FILE"
      if ! flock -n 200; then
        echo "Mover: another mover instance is already running — exiting"
        exit 0
      fi

      # Signal trap: immediately remove any in-flight temporary file if interrupted
      CURRENT_STAGING_DEST=""
      cleanup() {
        if [ -n "$CURRENT_STAGING_DEST" ] && [ -f "$CURRENT_STAGING_DEST" ]; then
          rm -f "$CURRENT_STAGING_DEST" 2>/dev/null || true
        fi
      }
      trap cleanup EXIT INT TERM

      # Fund 5: Cleanup stale staging files from previous interrupted runs (older than 24h)
      if [ -d "$ARCHIVE/.staging_mover" ]; then
        find "$ARCHIVE/.staging_mover" -type f -name 'tmp_*' -mtime +1 -delete
      fi

      # 1. Fill level check on Staging (Tier-B/SSD)
      FREE_KB=$(df -Pk "$STAGING" | awk 'NR==2 {print $4}')
      if [ "$FREE_KB" -ge "$MIN_FREE_KB" ]; then
        echo "Mover: enough free space ($(($FREE_KB/1024)) MB >= $(($MIN_FREE_KB/1024)) MB) — nothing to do"
        exit 0
      fi
      echo "Mover: SSD is low ($(($FREE_KB/1024)) MB free) → moving media to $ARCHIVE"

      # 2. Only whitelisted extensions AND >= 50MB, not modified in last 5 minutes (-mmin +5)
      mkdir -p "$ARCHIVE/.staging_mover"
      find "$STAGING" -type f -size +50M -mmin +5 \( ${
        lib.concatMapStringsSep " -o " (e: "-name '*${e}'") cfg.mediaExtensions
      } \) -print0 \
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

          # Target Collision Protection:
          # If destination already exists:
          # - Same size: file was already transferred (e.g. previous run interrupted before cleanup) -> remove staging file to free SSD
          # - Different size: warn and skip to prevent accidental overwrite or data loss
          if [ -e "$dest" ]; then
            SRC_SIZE=$(stat -c "%s" "$f" 2>/dev/null || echo "1")
            DEST_SIZE=$(stat -c "%s" "$dest" 2>/dev/null || echo "2")
            if [ "$SRC_SIZE" = "$DEST_SIZE" ]; then
              echo "Mover: destination already exists with identical size ($SRC_SIZE bytes) — removing duplicate from staging: $f"
              rm -f "$f"
              parent_dir="$(dirname "$f")"
              if [ "$parent_dir" != "$STAGING" ]; then
                rmdir "$parent_dir" 2>/dev/null || true
              fi
            else
              echo "Mover: WARNING: destination $dest already exists with DIFFERENT size (source: $SRC_SIZE, dest: $DEST_SIZE) — skipping" >&2
            fi
            continue
          fi

          # Pre-flight HDD Capacity Check: Ensure archive has space for file + 1GB safety margin
          FILE_SIZE_BYTES=$(stat -c "%s" "$f" 2>/dev/null || echo "0")
          FILE_SIZE_KB=$(( FILE_SIZE_BYTES / 1024 ))
          ARCHIVE_FREE_KB=$(df -Pk "$ARCHIVE" | awk 'NR==2 {print $4}')
          REQUIRED_KB=$(( FILE_SIZE_KB + 1024 * 1024 ))
          if [ "$ARCHIVE_FREE_KB" -lt "$REQUIRED_KB" ]; then
            echo "Mover: ARCHIVE $ARCHIVE is nearly full ($(($ARCHIVE_FREE_KB/1024)) MB free, need $(($REQUIRED_KB/1024)) MB) — skipping $rel" >&2
            continue
          fi

          # Atomic Publish Logic:
          # 1. Copy to a collision-free temporary file on the SAME filesystem (HDD cold backend)
          # 2. Atomic rename to the final destination so readers (Jellyfin via MergerFS) never see partial files
          staging_dest=$(mktemp -p "$ARCHIVE/.staging_mover" 'tmp_XXXXXX')
          CURRENT_STAGING_DEST="$staging_dest"
          mkdir -p "$(dirname "$dest")"

          echo "Mover: transferring $rel ..."
          if cp -f "$f" "$staging_dest" && mv -f "$staging_dest" "$dest"; then
            CURRENT_STAGING_DEST=""
            rm -f "$f"
            # Prune empty parent directory on staging (keep staging root intact)
            parent_dir="$(dirname "$f")"
            if [ "$parent_dir" != "$STAGING" ]; then
              rmdir "$parent_dir" 2>/dev/null || true
            fi
            echo "Mover: successfully moved $rel"
          else
            echo "Mover: ERROR moving $f — preserving source file" >&2
            rm -f "$staging_dest" 2>/dev/null || true
            CURRENT_STAGING_DEST=""
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
    # Limits real service starts if staging is noisy.
    unitConfig = {
      RequiresMountsFor = [
        cfg.stagingDir
        cfg.archiveDir
      ];
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
        ReadWritePaths = [
          cfg.stagingDir
          cfg.archiveDir
        ];
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
