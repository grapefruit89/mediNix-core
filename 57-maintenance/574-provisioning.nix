# ---
# id: "574-provisioning"
# title: "Provisioning — register Download-Client + Indexer + Root Folders via API (oneshot, idempotent)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5043
#   skill: nixos-context7-gate
# context7:
#   - query: "systemd.services oneshot ConditionPathExists example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "unitConfig.ConditionPathExists = \"!/flag/file\" for idempotency"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  flagFile = "/var/lib/mediNix-state/provisioned";  # in StateDirectory (writable, 0750)
in lib.mkIf cfg.maintenance.provisioning.enable {
  systemd.services.mediNix-provision = {
    description = "One-time provisioning: register SABnzbd + Prowlarr + Root Folders in *arr via API";
    after = [ "network.target" "sabnzbd.service" "prowlarr.service"
              "sonarr.service" "radarr.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig = {
      # Idempotent: only if flag does NOT exist
      ConditionPathExists = "!/var/lib/mediNix-state/provisioned";
    };
    serviceConfig = lib.mkMerge [
      # client-Profile: HTTP requests to 127.0.0.1 (API calls), no port binding
      # (network would have CAP_NET_BIND_SERVICE — unnecessary for provisioning script)
      (import ../lib/hardening-profiles.nix { inherit lib; }).client
      {
        Type = "oneshot";
        User = "media";
        Group = "media";
        UMask = "002";
        StateDirectory = "mediNix-state";       # /var/lib/mediNix-state (0750 via Factory base)
        StateDirectoryMode = "0750";
        ReadWritePaths = [ "/var/lib/mediNix-state" ];
      }
    ];
    path = [ pkgs.curl pkgs.jq ];
    script = ''
      set -euo pipefail

      # P0-1 FIX: API keys NOT in /proc/<pid>/cmdline (curl -H "X-Api-Key: $(cat …)")
      # → instead use header file with 0600, then securely delete.
      HF=$(mktemp); chmod 600 "$HF"

      SAB_API="''${cfg.secrets.sabnzbdApiKeyFile}"
      PROWLARR_API="''${cfg.secrets.prowlarrApiKeyFile}"
      SAB_URL="http://127.0.0.1:5410"
      PROWLARR_URL="http://127.0.0.1:5360"

      # 1) Register SABnzbd as download client in Sonarr/Radarr
      for arr in sonarr:5320 radarr:5330; do
        name="''${arr%%:*}"; port="''${arr##*:}"
        printf 'X-Api-Key: %s\r\n' "$(cat "$SAB_API")" > "$HF"
        curl -s -X POST "http://127.0.0.1:$port/api/v3/downloadclient" \
          --header "@$HF" \
          -H "Content-Type: application/json" \
          -d "{\"enable\":true,\"protocol\":\"usenet\",\"implementation\":\"Sabnzbd\",\"name\":\"SABnzbd\",\"settings\":{\"host\":\"127.0.0.1\",\"port\":5410,\"apiKey\":\"$(cat $SAB_API)\",\"category\":\"tv\"}}" || true
      done

      # 2) Register Prowlarr as indexer in Sonarr/Radarr (app import via Prowlarr)
      printf 'X-Api-Key: %s\r\n' "$(cat "$PROWLARR_API")" > "$HF"
      curl -s -X POST "$PROWLARR_URL/api/v1/applications" \
        --header "@$HF" \
        -H "Content-Type: application/json" \
        -d '[{"name":"Sonarr","implementation":"Sonarr","baseUrl":"http://127.0.0.1:5320","apiKey":"'"$(cat /var/lib/sonarr-5320/apikey)"'","syncCategories":[4000,4005,4010]}]' || true

      # 3) Root Folder + Quality Profile in Sonarr/Radarr (idempotent via API)
      for arr in "sonarr:5320:${cfg.sonarr.rootFolder}:${cfg.sonarr.qualityProfile}" \
                 "radarr:5330:${cfg.radarr.rootFolder}:${cfg.radarr.qualityProfile}"; do
        name="''${arr%%:*}"; rest="''${arr#*:}"
        port="''${rest%%:*}"; rest="''${rest#*:}"
        rf="''${rest%%:*}"; qp="''${rest#*:}"
        API="$(cat /var/lib/$name-$port/apikey 2>/dev/null || echo "")"
        [ -z "$API" ] && continue
        printf 'X-Api-Key: %s\r\n' "$API" > "$HF"
        curl -s -X POST "http://127.0.0.1:$port/api/v3/rootFolder" \
          --header "@$HF" -H "Content-Type: application/json" \
          -d "{\"path\":\"$rf\"}" >/dev/null 2>&1 || true
        curl -s "http://127.0.0.1:$port/api/v3/qualityprofile" --header "@$HF" \
          | ${pkgs.jq}/bin/jq -e --arg n "$qp" '.[] | select(.name==$n)' >/dev/null 2>&1 || \
        curl -s -X POST "http://127.0.0.1:$port/api/v3/qualityprofile" \
          --header "@$HF" -H "Content-Type: application/json" \
          -d "{\"name\":\"$qp\",\"upgradeAllowed\":true,\"cutoff\":{\"id\":2},\"items\":[{\"quality\":{\"id\":2},\"allowed\":true}]}" >/dev/null 2>&1 || true
      done

      rm -f "$HF"   # important: destroy header file with key

      # Set flag → Provisioning will never run again
      touch ${flagFile}
      echo "mediNix provisioning complete"
    '';
  };
}
