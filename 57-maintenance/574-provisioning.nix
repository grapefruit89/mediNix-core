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
  flagFile = "/var/lib/mediNix-state/provisioned";  # in StateDirectory (beschreibbar, 0750)
in lib.mkIf cfg.maintenance.provisioning.enable {
  systemd.services.mediNix-provision = {
    description = "One-time provisioning: register SABnzbd + Prowlarr + Root Folders in *arr via API";
    after = [ "network-online.target" "sabnzbd-5410.service" "prowlarr-5360.service"
              "sonarr-5320.service" "radarr-5330.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig = {
      # Idempotent: nur wenn Flag NICHT existiert
      ConditionPathExists = "!/var/lib/mediNix-state/provisioned";
    };
    serviceConfig = lib.mkMerge [
      # client-Profil: HTTP-Requests zu 127.0.0.1 (API-Calls), kein Port-Binding
      # (network hätte CAP_NET_BIND_SERVICE — unnötig für Provisioning-Skript)
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

      SAB_API="''${cfg.secrets.sabnzbdApiKeyFile}"
      PROWLARR_API="''${cfg.secrets.prowlarrApiKeyFile}"
      SAB_URL="http://127.0.0.1:5410"
      PROWLARR_URL="http://127.0.0.1:5360"

      # 1) SABnzbd als Download-Client in Sonarr/Radarr registrieren
      for arr in sonarr:5320 radarr:5330; do
        name="''${arr%%:*}"; port="''${arr##*:}"
        curl -s -X POST "http://127.0.0.1:$port/api/v3/downloadclient" \
          -H "X-Api-Key: *** $SAB_API)" \
          -H "Content-Type: application/json" \
          -d "{\"enable\":true,\"protocol\":\"usenet\",\"implementation\":\"Sabnzbd\",\"name\":\"SABnzbd\",\"settings\":{\"host\":\"127.0.0.1\",\"port\":5410,\"apiKey\":\"$(cat $SAB_API)\",\"category\":\"tv\"}}" || true
      done

      # 2) Prowlarr als Indexer in Sonarr/Radarr (App-Import via Prowlarr)
      curl -s -X POST "$PROWLARR_URL/api/v1/applications" \
        -H "X-Api-Key: *** $PROWLARR_API)" \
        -H "Content-Type: application/json" \
        -d '[{"name":"Sonarr","implementation":"Sonarr","baseUrl":"http://127.0.0.1:5320","apiKey":"'"$(cat /var/lib/sonarr-5320/apikey)"'","syncCategories":[4000,4005,4010]}]' || true

      # 3) Root Folder + Quality Profile in Sonarr/Radarr (idempotent via API)
      for arr in "sonarr:5320:${cfg.services.sonarr.rootFolder}:${cfg.services.sonarr.qualityProfile}" \
                 "radarr:5330:${cfg.services.radarr.rootFolder}:${cfg.services.radarr.qualityProfile}"; do
        name="''${arr%%:*}"; rest="''${arr#*:}"
        port="''${rest%%:*}"; rest="''${rest#*:}"
        rf="''${rest%%:*}"; qp="''${rest#*:}"
        API="$(cat /var/lib/$name-$port/apikey 2>/dev/null || echo "")"
        [ -z "$API" ] && continue
        curl -s -X POST "http://127.0.0.1:$port/api/v3/rootFolder" \
          -H "X-Api-Key: *** $API)" -H "Content-Type: application/json" \
          -d "{\"path\":\"$rf\"}" >/dev/null 2>&1 || true
        curl -s "http://127.0.0.1:$port/api/v3/qualityprofile" -H "X-Api-Key: *** $API)" \
          | ${pkgs.jq}/bin/jq -e --arg n "$qp" '.[] | select(.name==$n)' >/dev/null 2>&1 || \
        curl -s -X POST "http://127.0.0.1:$port/api/v3/qualityprofile" \
          -H "X-Api-Key: *** $API)" -H "Content-Type: application/json" \
          -d "{\"name\":\"$qp\",\"upgradeAllowed\":true,\"cutoff\":{\"id\":2},\"items\":[{\"quality\":{\"id\":2},\"allowed\":true}]}" >/dev/null 2>&1 || true
      done

      # Flag setzen → Provisioning läuft nie wieder
      touch ${flagFile}
      echo "mediNix provisioning complete"
    '';
  };
}
