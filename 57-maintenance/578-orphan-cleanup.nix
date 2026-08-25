# ---
# id: "578-orphan-cleanup"
# title: "Drift Detection & Orphan Cleanup"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-25
# links: ""
# provides: ["systemd.timers.medinix-orphan-cleanup"]
# requires: ["lib/registry", "options.medinix.knownStateDirs"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---

{ config, lib, pkgs, ... }:

let
  cfg = config.medinix;
  
  # Join all known directories into a bash array string
  knownDirsArray = lib.concatStringsSep " " (map (dir: "\"${dir}\"") cfg.knownStateDirs);
  
  cleanupScript = pkgs.writeShellScriptBin "medinix-orphan-cleanup" ''
    echo "[AI/Admin Context] Checking for orphaned app directories in /var/lib/medinix..."
    
    # We only care about /var/lib/medinix as agreed
    BASE_DIR="/var/lib/medinix"
    if [ ! -d "$BASE_DIR" ]; then
      echo "Base directory $BASE_DIR does not exist. Exiting."
      exit 0
    fi
    
    KNOWN_DIRS=(${knownDirsArray})
    
    # We always ignore the secrets folder and the crowdsec hash file
    IGNORED=("secrets" "CROWDSEC-HASH.md")
    
    ORPHANS_FOUND=0
    ORPHAN_LIST=""
    
    for dir in "$BASE_DIR"/*; do
      [ -e "$dir" ] || continue
      
      BASENAME=$(basename "$dir")
      
      # Check if ignored
      IS_IGNORED=0
      for ig in "''${IGNORED[@]}"; do
        if [ "$BASENAME" = "$ig" ]; then
          IS_IGNORED=1
          break
        fi
      done
      [ $IS_IGNORED -eq 1 ] && continue
      
      # Check if known
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
      ${pkgs.curl}/bin/curl -H "Title: mediNix Orphan Cleanup"            -H "Tags: warning,broom"            -H "Priority: 3"            -d "Found $ORPHANS_FOUND orphaned directories in /var/lib/medinix that are no longer managed by the Nix Flake: $ORPHAN_LIST"            "https://ntfy.sh/medinix-alerts-example" || true
    else
      echo "No orphans found. System is clean."
    fi
  '';

in {
  options.medinix.orphanCleanup = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the nightly orphan cleanup dry-run check";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.orphanCleanup.enable) {
    systemd.services.medinix-orphan-cleanup = {
      description = "mediNix Orphan Cleanup Check";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${cleanupScript}/bin/medinix-orphan-cleanup";
        User = "root";
      };
    };

    systemd.timers.medinix-orphan-cleanup = {
      description = "Run mediNix Orphan Cleanup Check nightly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 03:00:00"; # Run at 3 AM
        Persistent = true;
      };
    };
  };
}
