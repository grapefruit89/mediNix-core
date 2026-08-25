# ---
# id: "575-update-notifier"
# title: "Update Notifier — checks mediNix-core flake for new version, notifies via ntfy"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links: 
# provides: []
# requires: ["lib/registry"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5043
# skill: nixos-context7-gate
# note: "NO auto-update. Only notifies. User decides when to rebuild."
# context7: 
# - query: "systemd.timers OnCalendar daily example"
# library: /websites/nixos_manual_nixos_unstable
# snippet: "timerConfig.OnCalendar = \"daily\" for scheduled checks"
# ---

{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.maintenance.updateNotifier;
  # ntfy topic from observability.ntfy (if ntfy is running)
  ntfyTopic = config.medinix.observability.ntfy.topic or "mediNix-updates";
  ntfyPort  = 5810;
in lib.mkIf cfg.enable {
  # Daily check: is a new mediNix-core version available?
  systemd.timers.mediNix-update-notifier = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  systemd.services.mediNix-update-notifier = {
    description = "Check mediNix-core flake for updates (notify only, no auto-update)";
    serviceConfig = lib.mkMerge [
      # client profile: HTTP requests (flake metadata + ntfy), no port binding
      (import ../lib/hardening-profiles.nix { inherit lib; }).client
      {
        Type = "oneshot";
        User = "media";
        Group = "media";
        # nix flake metadata requires nix-daemon-socket (ProtectSystem=strict
        # + PrivateTmp block /nix/var/nix/daemon-socket otherwise)
        BindReadOnlyPaths = [ "/nix/var/nix/daemon-socket" ];
      }
    ];
    path = [ pkgs.nix pkgs.jq pkgs.curl ];  # nix + jq + curl explicitly in PATH
    script = ''
      set -euo pipefail
      # Remote lastModified (GitHub HEAD of mediNix-core)
      current=$(nix flake metadata github:grapefruit89/mediNix-core --json 2>/dev/null \
        | jq -r '.locks.nodes."mediNix-core".locked.lastModified' || echo "0")
      # Local lock lastModified
      local=$(nix flake metadata . --json 2>/dev/null \
        | jq -r '.locks.nodes."mediNix-core".locked.lastModified' || echo "0")

      if [ "$current" != "$local" ] && [ "$current" != "0" ]; then
        msg="mediNix-core update available (remote=$current, local=$local) — please run nixos-rebuild"
        curl -s -d "$msg" "http://127.0.0.1:${toString ntfyPort}/${ntfyTopic}" || true
        echo "$msg"
      else
        echo "mediNix-core is up to date (local=$local)"
      fi
    '';
  };
}
