# ---
# id: "575-update-notifier"
# title: "Update Notifier — checks mediNix-core flake for new version, notifies via ntfy"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5043
#   skill: nixos-context7-gate
#   note: "NO auto-update. Only notifies. User decides when to rebuild."
# context7:
#   - query: "systemd.timers OnCalendar daily example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "timerConfig.OnCalendar = \"daily\" for scheduled checks"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.maintenance.updateNotifier;
  # ntfy-Topic aus observability.ntfy (falls ntfy läuft)
  ntfyTopic = config.grapefruitMedia.observability.ntfy.topic or "mediNix-updates";
  ntfyPort  = 5810;
in lib.mkIf cfg.enable {
  # Daily check: ist eine neue mediNix-core Version verfügbar?
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
      # client-Profil: HTTP-Requests (flake metadata + ntfy), kein Port-Binding
      (import ../lib/hardening-profiles.nix { inherit lib; }).client
      {
        Type = "oneshot";
        User = "media";
        Group = "media";
      }
    ];
    path = [ pkgs.nix pkgs.jq pkgs.curl ];  # nix + jq + curl explizit in PATH
    script = ''
      set -euo pipefail
      # Remote lastModified (GitHub HEAD von mediNix-core)
      current=$(nix flake metadata github:grapefruit89/mediNix-core --json 2>/dev/null \
        | jq -r '.locks.nodes."mediNix-core".locked.lastModified' || echo "0")
      # Lokaler Lock lastModified
      local=$(nix flake metadata . --json 2>/dev/null \
        | jq -r '.locks.nodes."mediNix-core".locked.lastModified' || echo "0")

      if [ "$current" != "$local" ] && [ "$current" != "0" ]; then
        msg="mediNix-core Update verfügbar (remote=$current, local=$local) — bitte nixos-rebuild ausführen"
        curl -s -d "$msg" "http://127.0.0.1:${toString ntfyPort}/${ntfyTopic}" || true
        echo "$msg"
      else
        echo "mediNix-core ist aktuell (local=$local)"
      fi
    '';
  };
}
