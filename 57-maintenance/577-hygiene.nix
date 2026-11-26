# ---
# id: "577-hygiene"
# title: "System Hygiene — State Directory Drift Detection & Orphan Cleanup (57-maintenance)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-11-26
# links:
#   adr: ADR-578, ADR-5043, ADR-5050
# provides: ["systemd.timers.medinix-orphan-cleanup", "systemd.timers.mediNix-drift-detection"]
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
# Kanonisches Hygiene-Modul fuer mediNix (ADR-578):
#   1. Drift Detection (alle 30 Min): State-Dir Permissions (GID 5000), Tier-Mounts & Secrets
#   2. Orphan Cleanup (nächtlich 03:00): Findet verwaiste Ordner unter /var/lib/medinix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix;
  profiles = import ../50-core/hardening-profiles.nix { inherit lib; };
  df = import ../50-core/derive.nix;
  ntfyPort = (import ../50-core/registry.nix { inherit lib; }).services.ntfy.port;
  driftNtfy = "http://127.0.0.1:${toString ntfyPort}/mediNix-drift";

  # ── Drift Detection Skript ─────────────────────────────────────────────────
  driftScript = pkgs.writeShellApplication {
    name = "mediNix-drift-detection";
    runtimeInputs = [
      pkgs.findutils
      pkgs.coreutils
      pkgs.curl
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail
      NTFY="${driftNtfy}"

      # 1. All state dirs must belong to GID 5000 (media)
      find /var/lib -maxdepth 1 -name "*-5[0-9][0-9][0-9]" -type d 2>/dev/null | \
      while read -r dir; do
        gid=$(stat -c %g "$dir")
        if [ "$gid" != "${toString df.sharedGid}" ]; then
          curl -s -d "DRIFT: $dir has GID $gid instead of ${toString df.sharedGid} (media)" "$NTFY" || true
        fi
      done

      # 2. Tier-C (Media HDD) mounted?
      MEDIA_ROOT="${toString cfg.storage.mediaRoot}"
      if [ -n "$MEDIA_ROOT" ] && ! mountpoint -q "$MEDIA_ROOT" 2>/dev/null; then
        curl -s -d "CRITICAL: Tier-C ($MEDIA_ROOT) not mounted!" "$NTFY" || true
      fi

      # 3. Tier-B (Downloads-SSD) mounted?
      DOWNLOADS="$MEDIA_ROOT/downloads"
      if [ -d "$DOWNLOADS" ] && ! mountpoint -q "$DOWNLOADS" 2>/dev/null; then
        curl -s -d "WARNING: Tier-B ($DOWNLOADS) not mounted!" "$NTFY" || true
      fi

      # 4. Configured secret files present + not empty (DO NOT log content)
      for sec in "${toString cfg.secrets.sabnzbdApiKeyFile}" \
                 "${toString cfg.secrets.prowlarrApiKeyFile}" \
                 "${toString cfg.secrets.jellyfinAdminPasswordFile}" \
                 "${toString cfg.secrets.navidromeOidcFile}"; do
        if [ -n "$sec" ] && { [ ! -f "$sec" ] || [ ! -s "$sec" ]; }; then
          curl -s -d "DRIFT: Secret missing/empty: $sec" "$NTFY" || true
        fi
      done

      echo "Drift-Detection OK"
    '';
  };

  # ── Orphan Cleanup Skript ──────────────────────────────────────────────────
  knownDirsArray = lib.concatStringsSep " " (map (dir: "\"${dir}\"") cfg.knownStateDirs);

  orphanScript = pkgs.writeShellScriptBin "medinix-orphan-cleanup" ''
        echo "[AI/Admin Context] Checking for orphaned app directories in /var/lib/medinix..."

        BASE_DIR="/var/lib/medinix"
        if [ ! -d "$BASE_DIR" ]; then
          echo "Base directory $BASE_DIR does not exist. Exiting."
          exit 0
        fi

        KNOWN_DIRS=(${knownDirsArray})
        IGNORED=("secrets" "CROWDSEC-HASH.md")

        ORPHANS_FOUND=0
        ORPHAN_LIST=""

        for dir in "$BASE_DIR"/*; do
          [ -e "$dir" ] || continue

          BASENAME=$(basename "$dir")
          IS_IGNORED=0
          for ig in "''${IGNORED[@]}"; do
            if [ "$BASENAME" = "$ig" ]; then
              IS_IGNORED=1
              break
            fi
          done
          [ $IS_IGNORED -eq 1 ] && continue

          IS_KNOWN=0
          for known in "''${KNOWN_DIRS[@]}"; do
            if [ "$dir" = "$known" ]; then
              IS_KNOWN=1
              break
            fi
          done

          if [ $IS_KNOWN -eq 0 ]; then
            echo "WARNING: Orphaned directory found: $dir"
            ORPHANS_FOUND=$((ORPHANS_FOUND + 1))
            ORPHAN_LIST="$ORPHAN_LIST
    - $dir"
          fi
        done

        if [ $ORPHANS_FOUND -gt 0 ]; then
          echo "Found $ORPHANS_FOUND orphans. Sending Ntfy alert..."
          ${pkgs.curl}/bin/curl -H "Title: mediNix Orphan Cleanup" \
            -H "Tags: warning,broom" \
            -H "Priority: 3" \
            -d "Found $ORPHANS_FOUND orphaned directories in /var/lib/medinix that are no longer managed by the Nix Flake: $ORPHAN_LIST" \
            "http://127.0.0.1:${toString ntfyPort}/alerts" || true
        else
          echo "No orphans found. System is clean."
        fi
  '';
in
{
  options.medinix.orphanCleanup = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the nightly orphan cleanup dry-run check";
    };
  };

  config = lib.mkMerge [
    # ── Drift Detection (alle 30 Min) ────────────────────────────────────────
    (lib.mkIf (cfg.enable && cfg.observability.driftDetection) {
      systemd.timers.mediNix-drift-detection = {
        wantedBy = [ "timers.target" ];
        timerConfig.OnCalendar = "*:0/30";
      };

      systemd.services.mediNix-drift-detection = {
        serviceConfig = lib.mkMerge [
          profiles.script
          {
            Type = "oneshot";
            RateLimitBurst = 5;
            RateLimitIntervalSec = "30s";
          }
        ];
        path = [
          pkgs.findutils
          pkgs.coreutils
          pkgs.curl
          pkgs.util-linux
        ];
        script = "${lib.getExe driftScript}";
      };
    })

    # ── Orphan Cleanup (nächtlich 03:00) ──────────────────────────────────────
    (lib.mkIf (cfg.enable && cfg.orphanCleanup.enable) {
      systemd.services.medinix-orphan-cleanup = {
        description = "mediNix Orphan Cleanup Check";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${orphanScript}/bin/medinix-orphan-cleanup";
          User = "root";
        };
      };

      systemd.timers.medinix-orphan-cleanup = {
        description = "Run mediNix Orphan Cleanup Check nightly";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 03:00:00";
          Persistent = true;
        };
      };
    })
  ];
}
