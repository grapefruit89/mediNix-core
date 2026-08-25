# ---
# id: "577-drift-detection"
# title: "Drift-Detection — State-Dir-Permissions + Tier-Mounts (every 30 Min)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-12
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
# adr: ADR-5043, ADR-5050
# repo-harvest: Nix-Grok (drift-detection pattern)
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix;
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  ntfy = "http://127.0.0.1:5810/mediNix-drift";

  script = pkgs.writeShellApplication {
    name = "mediNix-drift-detection";
    runtimeInputs = [ pkgs.findutils pkgs.coreutils pkgs.curl pkgs.util-linux ];
    text = ''
      set -euo pipefail
      NTFY="${ntfy}"

      # 1. All state dirs must belong to GID 5000 (media)
      find /var/lib -maxdepth 1 -name "*-5[0-9][0-9][0-9]" -type d 2>/dev/null | \
      while read -r dir; do
        gid=$(stat -c %g "$dir")
        if [ "$gid" != "5000" ]; then
          curl -s -d "DRIFT: $dir has GID $gid instead of 5000 (media)" "$NTFY" || true
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
in
lib.mkIf (cfg.enable && cfg.observability.driftDetection) {
  systemd.timers.mediNix-drift-detection = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "*:0/30";  # every 30 minutes
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
    path = [ pkgs.findutils pkgs.coreutils pkgs.curl pkgs.util-linux ];
    script = "${lib.getExe script}";
  };
}
