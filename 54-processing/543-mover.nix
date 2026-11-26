# ---
# id: "543-mover"
# title: "Piggyback Tier-B→Tier-C Mover (write-batching release folders without HDD wake or stream contention)"
# domain: 54
# folder: 54-processing
# status: active
# complexity: 2
# last_reviewed: 2026-11-26
# links:
#   adr: ADR-543, ADR-5000
# provides: []
# requires: ["50-core/hardening-profiles"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# skill: medinix-implement-discipline
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
  active = svc.enable && cfg.enable && cfg.mode != "off";

  stagingStr = lib.optionalString (cfg.stagingDir != null) (toString cfg.stagingDir);
  archiveStr = lib.optionalString (cfg.archiveDir != null) (toString cfg.archiveDir);
  metaStr = toString svc.storage.metadataDir;

  moverScript = pkgs.writeShellApplication {
    name = "mediNix-mover";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.util-linux
      pkgs.hdparm
    ];
    text = ''
      set -euo pipefail

      STAGING="${stagingStr}"
      ARCHIVE="${archiveStr}"
      MIN_FREE_KB=$(( ${toString cfg.minFreeGb} * 1024 * 1024 ))
      CRIT_FREE_KB=$(( ${toString cfg.criticalFreeGb} * 1024 * 1024 ))
      IDLE_READ_MAX_SECTORS=$(( ${toString cfg.idleReadThresholdKb} * 2 ))
      STATE_FILE="/run/medinix-mover/last_read_sectors"

      # Gate 1: Pfade & Mount-Schutz (0 HDD-Zugriff)
      [ -d "$STAGING" ] && [ -d "$ARCHIVE" ] || { echo "Mover: mount missing"; exit 1; }
      [ "$STAGING" != "$ARCHIVE" ]           || { echo "Mover: same path"; exit 1; }
      ARCHIVE_MNT="$(stat -c %m "$ARCHIVE")"
      [ "$ARCHIVE_MNT" != "/" ]              || { echo "Mover: archive on root"; exit 1; }
      [ "$(findmnt -n -o FSTYPE --target "$ARCHIVE" 2>/dev/null || true)" != "fuse.mergerfs" ] || {
        echo "Mover: archiveDir must be physical Tier-3 mount, not mergerfs"; exit 1;
      }

      # Gate 2: SSD-Fuellstand + Video-Kandidaten (0 HDD-Zugriff; nur Videocontainer >= minFileSize)
      free_kb=$(df -Pk "$STAGING" | awk 'NR==2{print $4}')
      [ "$free_kb" -ge "$MIN_FREE_KB" ] && exit 0
      mapfile -d $'\0' candidates < <(
        find "$STAGING" \
          ${
            lib.optionalString (
              !cfg.moveAudiobooks
            ) ''\( -path "$STAGING/audiobooks" -o -path "*/audiobooks" \) -prune -o''
          } \
          -type f -size "+${cfg.minFileSize}" ! -mmin -5 \
          \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.m4v' -o -iname '*.ts' \) \
          -print0 | sort -z
      )
      [ "''${#candidates[@]}" -gt 0 ] || exit 0

      # Gate 3 + 4: Piggybacking & I/O-Contention-Schutz (HDD dreht, kein aktiver Stream)
      resolve_disk() {
        local src dev pk
        ${
          if cfg.archiveDevice != null then
            ''dev="$(readlink -f "${cfg.archiveDevice}")"''
          else
            ''
              src="$(findmnt -n -o SOURCE --target "$ARCHIVE" 2>/dev/null || true)"
              dev="$(readlink -f "$src" 2>/dev/null || true)"
            ''
        }
        [ -b "$dev" ] || return 1
        pk="$(lsblk -no PKNAME "$dev" 2>/dev/null | head -n1 || true)"
        if [ -n "$pk" ] && [ -b "/dev/$pk" ]; then echo "/dev/$pk"; else echo "$dev"; fi
      }

      hdd_awake() {
        local rot
        rot="$(cat "/sys/block/''${1##*/}/queue/rotational" 2>/dev/null || echo 1)"
        [ "$rot" = "0" ] && return 0
        hdparm -C "$1" 2>/dev/null | grep -q 'active/idle'
      }

      hdd_busy_reading() {
        local stat_file="/sys/block/''${1##*/}/stat"
        [ -r "$stat_file" ] || return 1
        local read_sectors in_flight prev_sectors delta
        read -r _ _ read_sectors _ _ _ _ _ in_flight _ < "$stat_file"
        [ "$in_flight" -gt 0 ] && return 0
        if [ ! -r "$STATE_FILE" ]; then
          printf '%s\n' "$read_sectors" > "$STATE_FILE"
          return 0
        fi
        prev_sectors="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
        printf '%s\n' "$read_sectors" > "$STATE_FILE"
        delta=$(( read_sectors - prev_sectors ))
        [ "$delta" -gt "$IDLE_READ_MAX_SECTORS" ]
      }

      DISK="$(resolve_disk || true)"
      if [ -n "$DISK" ]; then
        if [ "$free_kb" -ge "$CRIT_FREE_KB" ]; then
          hdd_awake "$DISK" || { echo "Mover: defer — archive asleep ($((free_kb/1024)) MB free)"; exit 0; }
          hdd_busy_reading "$DISK" && { echo "Mover: defer — archive serving active reads"; exit 0; }
        elif ! hdd_awake "$DISK"; then
          echo "Mover: WAKE — critical SSD space ($((free_kb/1024)) MB free < $((CRIT_FREE_KB/1024)) MB)"
        fi
      fi

      # Arbeit: ausschließlich gefilterte Videodateien atomar verschieben (Temp ausserhalb der Union)
      LOCK_FILE="/run/medinix-mover/mover.lock"
      exec 200>"$LOCK_FILE"
      flock -n 200 || exit 0

      TMP="$ARCHIVE_MNT/.mover-tmp"
      mkdir -p "$TMP" 2>/dev/null || { TMP="$(dirname "$ARCHIVE")/.mover-tmp"; mkdir -p "$TMP"; }
      find "$TMP" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

      CURRENT_TMP=""
      cleanup() { [ -n "$CURRENT_TMP" ] && rm -f "$CURRENT_TMP" 2>/dev/null || true; }
      trap cleanup EXIT INT TERM

      for src_file in "''${candidates[@]}"; do
        [ -f "$src_file" ] || continue
        [ "$(df -Pk "$STAGING" | awk 'NR==2{print $4}')" -ge "$MIN_FREE_KB" ] && break

        rel="''${src_file#"$STAGING"/}"
        dst="$ARCHIVE/$rel"
        [ -e "$dst" ] && { echo "Mover: collision $rel — skip"; continue; }

        tmp_file="$(mktemp -p "$TMP" 'mov_XXXXXX')"
        CURRENT_TMP="$tmp_file"
        mkdir -p "$(dirname "$dst")"

        if ionice -c 3 cp -a --reflink=auto "$src_file" "$tmp_file" \
           && sync -f "$tmp_file" \
           && mv -T "$tmp_file" "$dst"; then
          CURRENT_TMP=""
          rm -f "$src_file"
          parent="$(dirname "$src_file")"
          while [ "$parent" != "$STAGING" ] && rmdir "$parent" 2>/dev/null; do
            parent="$(dirname "$parent")"
          done
          echo "Mover: moved $rel"
        else
          rm -f "$tmp_file" 2>/dev/null || true
          CURRENT_TMP=""
        fi
      done

      if [ -n "$DISK" ] && [ -r "/sys/block/''${DISK##*/}/stat" ]; then
        awk '{print $3}' "/sys/block/''${DISK##*/}/stat" > "$STATE_FILE" 2>/dev/null || true
      fi
    '';
  };
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !active || (cfg.stagingDir != null && cfg.archiveDir != null);
          message = "[mediNix/543-mover] stagingDir und archiveDir muessen explizit gesetzt sein (kein Fail-Open-Default).";
        }
        {
          assertion = !active || stagingStr != archiveStr;
          message = "[mediNix/543-mover] stagingDir und archiveDir duerfen nicht identisch sein.";
        }
        {
          assertion = !active || !(svc.storage.backends ? hot) || stagingStr != svc.storage.backends.hot;
          message = "[mediNix/543-mover] stagingDir darf nicht direkt auf backends.hot zeigen (enthaelt cache/metadata). Waehle einen Medien-Unterpfad.";
        }
        {
          assertion = !active || !(svc.storage.backends ? cold) || archiveStr != svc.storage.backends.cold;
          message = "[mediNix/543-mover] archiveDir darf nicht direkt auf backends.cold zeigen. Waehle einen Medien-Unterpfad.";
        }
        {
          assertion =
            !active
            || (
              stagingStr != metaStr
              && !(lib.hasPrefix "${metaStr}/" stagingStr)
              && !(lib.hasPrefix "${stagingStr}/" metaStr)
            );
          message = "[mediNix/543-mover] stagingDir darf nicht mit storage.metadataDir ueberlappen (Tier-1 Metadaten sind unantastbar).";
        }
        {
          assertion = !active || (cfg.criticalFreeGb >= 0 && cfg.criticalFreeGb < cfg.minFreeGb);
          message = "[mediNix/543-mover] criticalFreeGb muss >= 0 und strikt < minFreeGb sein.";
        }
        {
          assertion = !active || cfg.moveAudiobooks || (builtins.baseNameOf stagingStr != "audiobooks");
          message = "[mediNix/543-mover] Audiobooks verbleiben standardmaessig auf Tier-B (SSD). Setze moveAudiobooks = true fuer Tier-C.";
        }
      ];
    }

    (lib.mkIf active {
      systemd.services.mediNix-mover = {
        description = "Piggyback Tier-B→Tier-C Mover (write-batching release folders)";
        unitConfig = {
          RequiresMountsFor = lib.optionals (cfg.stagingDir != null && cfg.archiveDir != null) [
            stagingStr
            archiveStr
          ];
        };
        serviceConfig = (import ../50-core/hardening-profiles.nix { inherit lib; }).script // {
          Type = "oneshot";
          User = "root";
          Group = "root";
          PrivateDevices = false;
          CapabilityBoundingSet = [
            "CAP_SYS_RAWIO"
            "CAP_DAC_OVERRIDE"
            "CAP_DAC_READ_SEARCH"
            "CAP_CHOWN"
            "CAP_FOWNER"
          ];
          IOSchedulingClass = "idle";
          Nice = 19;
          RuntimeDirectory = "medinix-mover";
          ReadWritePaths = lib.unique (
            lib.optionals (cfg.stagingDir != null) [ stagingStr ]
            ++ lib.optionals (cfg.archiveDir != null) [
              archiveStr
              (builtins.dirOf archiveStr)
            ]
            ++ lib.optional (svc.storage.backends ? cold) svc.storage.backends.cold
          );
        };
        script = "${lib.getExe moverScript}";
      };

      systemd.timers.mediNix-mover = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnUnitInactiveSec = cfg.piggybackInterval;
          OnBootSec = cfg.piggybackInterval;
          Unit = "mediNix-mover.service";
        };
      };
    })
  ];
}
