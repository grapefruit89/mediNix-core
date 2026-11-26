# ---
# id: "570-storage"
# title: "Storage Tiering, Spindown, Power-Logging & Piggyback-Mover (57-maintenance)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-11-26
# links:
#   adr: ADR-570, ADR-543
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
# ---
# Kanonisches Storage-, Tiering- und Spindown-Zentrum (ADR-570, ADR-543).
#
# Vereint:
#   1. Verzeichnis-Tiering, tmpfiles (2775 root:media) & MergerFS Mount-Optionen
#   2. Kernel Dentry/Inode-Cache (sysctl vm.vfs_cache_pressure = 10)
#   3. ATA HDD Spindown-Timeout (hdparm -S 244 -> 120m)
#   4. Lautloses Spindown/Spin-up Power-Event-Logging (journald: medinix-disk-power)
#   5. Piggyback Tier-B→Tier-C Mover (Write-Batching ohne Plattenwecken oder Stream-Contention)
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix;
  st = cfg.storage;
  mv = cfg.mover;
  dh = cfg.diskHealth;

  profiles = import ../50-core/hardening-profiles.nix { inherit lib; };

  tiers = lib.optionals (st.backends ? hot && st.backends ? cold) [
    st.backends.hot
    st.backends.cold
  ];
  mediaTypes = [
    "movies"
    "series"
    "books"
    "audiobooks"
    "music"
  ];

  # ── Spindown & Power-Logging Helfer ──────────────────────────────────────────
  # ATA spindown encoding (hdparm -S): 1..240 = N*5s (<=20m), 241..251 = (N-240)*30m (120m => 244)
  spindownArg =
    let
      m = dh.spindownDelayMinutes;
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
      if dh.devices == [ "DEVICESCAN" ] then
        ''
          for sysdev in /sys/block/sd*; do
            [ -e "$sysdev/queue/rotational" ] || continue
            [ "$(cat "$sysdev/queue/rotational" 2>/dev/null || echo 0)" = "1" ] || continue
            disks+=("/dev/''${sysdev##*/}")
          done
        ''
      else
        ''
          raw_devices=(${lib.escapeShellArgs dh.devices})
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
    name = "medinix-disk-spindown";
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
    name = "medinix-disk-power";
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

  # ── Mover Helfer & Skript ──────────────────────────────────────────────────
  moverActive = cfg.enable && mv.enable && mv.mode != "off";
  stagingStr = lib.optionalString (mv.stagingDir != null) (toString mv.stagingDir);
  archiveStr = lib.optionalString (mv.archiveDir != null) (toString mv.archiveDir);
  metaStr = toString st.metadataDir;

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
      MIN_FREE_KB=$(( ${toString mv.minFreeGb} * 1024 * 1024 ))
      CRIT_FREE_KB=$(( ${toString mv.criticalFreeGb} * 1024 * 1024 ))
      IDLE_READ_MAX_SECTORS=$(( ${toString mv.idleReadThresholdKb} * 2 ))
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
              !mv.moveAudiobooks
            ) ''\( -path "$STAGING/audiobooks" -o -path "*/audiobooks" \) -prune -o''
          } \
          -type f -size "+${mv.minFileSize}" ! -mmin -5 \
          \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.m4v' -o -iname '*.ts' \) \
          -print0 | sort -z
      )
      [ "''${#candidates[@]}" -gt 0 ] || exit 0

      # Gate 3 + 4: Piggybacking & I/O-Contention-Schutz (HDD dreht, kein aktiver Stream)
      resolve_disk() {
        local src dev pk
        ${
          if mv.archiveDevice != null then
            ''dev="$(readlink -f "${mv.archiveDevice}")"''
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
          assertion =
            (!cfg.enable || !st.enable)
            || st.backends == { }
            || (
              st.backends ? hot && st.backends ? cold && builtins.length (builtins.attrNames st.backends) == 2
            );
          message = "[mediNix/570-storage] storage.backends: entweder {} (Simple) oder exakt { hot; cold; } (Tiered, ADR-570).";
        }
        {
          assertion = !moverActive || (mv.stagingDir != null && mv.archiveDir != null);
          message = "[mediNix/570-storage] mover: stagingDir und archiveDir muessen explizit gesetzt sein (kein Fail-Open-Default).";
        }
        {
          assertion = !moverActive || stagingStr != archiveStr;
          message = "[mediNix/570-storage] mover: stagingDir und archiveDir duerfen nicht identisch sein.";
        }
        {
          assertion = !moverActive || !(st.backends ? hot) || stagingStr != st.backends.hot;
          message = "[mediNix/570-storage] mover: stagingDir darf nicht direkt auf backends.hot zeigen (enthaelt cache/metadata). Waehle einen Medien-Unterpfad.";
        }
        {
          assertion = !moverActive || !(st.backends ? cold) || archiveStr != st.backends.cold;
          message = "[mediNix/570-storage] mover: archiveDir darf nicht direkt auf backends.cold zeigen. Waehle einen Medien-Unterpfad.";
        }
        {
          assertion =
            !moverActive
            || (
              stagingStr != metaStr
              && !(lib.hasPrefix "${metaStr}/" stagingStr)
              && !(lib.hasPrefix "${stagingStr}/" metaStr)
            );
          message = "[mediNix/570-storage] mover: stagingDir darf nicht mit storage.metadataDir ueberlappen (Tier-1 Metadaten sind unantastbar).";
        }
        {
          assertion = !moverActive || (mv.criticalFreeGb >= 0 && mv.criticalFreeGb < mv.minFreeGb);
          message = "[mediNix/570-storage] mover: criticalFreeGb muss >= 0 und strikt < minFreeGb sein.";
        }
        {
          assertion = !moverActive || mv.moveAudiobooks || (builtins.baseNameOf stagingStr != "audiobooks");
          message = "[mediNix/570-storage] mover: Audiobooks verbleiben standardmaessig auf Tier-B (SSD). Setze moveAudiobooks = true fuer Tier-C.";
        }
      ];
    }

    # ── Tiering, Verzeichnisse & Kernel Dentry-Cache ────────────────────────────
    (lib.mkIf (cfg.enable && st.enable) {
      users.groups.media = lib.mkDefault { gid = (import ../50-core/derive.nix).sharedGid; };

      boot.kernel.sysctl."vm.vfs_cache_pressure" = lib.mkDefault 10;

      medinix.recommended.mountOptions = {
        hdd = [
          "noatime"
          "nofail"
          "x-systemd.device-timeout=10s"
        ];
        mergerfs = [
          "defaults"
          "allow_other"
          "use_ino"
          "category.create=ff"
          "moveonenospc=mfs"
          "minfreespace=50G"
          "cache.readdir=true"
          "cache.entry=30"
          "cache.negative_entry=30"
          "cache.statfs=30"
          "cache.symlinks=true"
          "dropcacheonclose=true"
        ];
      };

      systemd.tmpfiles.rules = map (d: "d '${d}' 2775 root media -") (
        [
          (toString st.metadataDir)
          (toString st.downloadDir)
        ]
        ++ lib.concatMap (t: map (m: "${t}/${m}") mediaTypes) tiers
        ++ map (m: "${st.mediaRoot}/${m}") mediaTypes
      );
    })

    # ── Spindown Timeout & Power Transition Logging ───────────────────────────
    (lib.mkIf (cfg.enable && dh.enable) {
      systemd.services.medinix-disk-spindown = lib.mkIf (dh.spindownDelayMinutes > 0) {
        description = "Configure ATA HDD spindown delay (${toString dh.spindownDelayMinutes}m -> hdparm -S ${toString spindownArg})";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        serviceConfig = diskUnitConfig // {
          RemainAfterExit = true;
        };
        script = "${lib.getExe spindownScript}";
      };

      systemd.services.medinix-disk-power = lib.mkIf dh.powerLogging {
        description = "Silent HDD standby/spin-up power transition logger (hdparm -C)";
        serviceConfig = diskUnitConfig // {
          SyslogIdentifier = "medinix-disk-power";
          RuntimeDirectory = "medinix-disk-power";
          RuntimeDirectoryPreserve = "yes";
        };
        script = "${lib.getExe powerLogScript}";
      };

      systemd.timers.medinix-disk-power = lib.mkIf dh.powerLogging {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = dh.powerCheckInterval;
          OnUnitActiveSec = dh.powerCheckInterval;
          Unit = "medinix-disk-power.service";
        };
      };
    })

    # ── Piggyback-Mover Service & Timer ────────────────────────────────────────
    (lib.mkIf moverActive {
      systemd.services.mediNix-mover = {
        description = "Piggyback Tier-B→Tier-C Mover (write-batching release folders)";
        unitConfig = {
          RequiresMountsFor = lib.optionals (mv.stagingDir != null && mv.archiveDir != null) [
            stagingStr
            archiveStr
          ];
        };
        serviceConfig = profiles.script // {
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
            lib.optionals (mv.stagingDir != null) [ stagingStr ]
            ++ lib.optionals (mv.archiveDir != null) [
              archiveStr
              (builtins.dirOf archiveStr)
            ]
            ++ lib.optional (st.backends ? cold) st.backends.cold
          );
        };
        script = "${lib.getExe moverScript}";
      };

      systemd.timers.mediNix-mover = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnUnitInactiveSec = mv.piggybackInterval;
          OnBootSec = mv.piggybackInterval;
          Unit = "mediNix-mover.service";
        };
      };
    })
  ];
}
