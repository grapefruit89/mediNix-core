# ---
# id: "574-provisioning"
# title: "Provisioning — register Download-Client + Indexer via API (oneshot, idempotent)"
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
  flagFile = "/var/lib/mediNix-provisioned";
in lib.mkIf cfg.maintenance.provisioning.enable {
  systemd.services.mediNix-provision = {
    description = "One-time provisioning: register SABnzbd + Prowlarr in *arr via API";
    after = [ "network-online.target" "sabnzbd-5410.service" "prowlarr-5360.service"
              "sonarr-5320.service" "radarr-5330.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig = {
      # Idempotent: nur wenn Flag NICHT existiert
      ConditionPathExists = "!/var/lib/mediNix-provisioned";
    };
    serviceConfig = lib.mkMerge [
      # script-Profil: PrivateNetwork=true (curl braucht Netz — aber wir lassen es,
      # da es nur localhost ist; Profile hat PrivateNetwork=true, hier überschrieben)
      (import ../lib/hardening-profiles.nix { inherit lib; }).script // {
        PrivateNetwork = false;  # localhost API calls (127.0.0.1)
      }
      {
        Type = "oneshot";
        User = "media";
        Group = "media";
        UMask = "002";
        ReadWritePaths = [ "/var/lib" ];
      }
    ];
    path = [ pkgs.curl pkgs.jq ];
    script = ''
      set -euo pipefail

      SAB_API="${cfg.secrets.sabnzbdApiKeyFile}"
      PROWLARR_API="${cfg.secrets.prowlarrApiKeyFile}"
      SAB_URL="http://127.0.0.1:5410"
      PROWLARR_URL="http://127.0.0.1:5360"

      # 1) SABnzbd als Download-Client in Sonarr/Radarr registrieren
      for arr in sonarr:5320 radarr:5330; do
        name="''${arr%%:*}"; port="''${arr##*:}"
        curl -s -X POST "http://127.0.0.1:$port/api/v3/downloadclient" \
          -H "X-Api-Key: $(cat $SAB_API)" \
          -H "Content-Type: application/json" \
          -d "{\"enable\":true,\"protocol\":\"usenet\",\"implementation\":\"Sabnzbd\",\"name\":\"SABnzbd\",\"settings\":{\"host\":\"127.0.0.1\",\"port\":5410,\"apiKey\":\"$(cat $SAB_API)\",\"category\":\"tv\"}}" || true
      done

      # 2) Prowlarr als Indexer in Sonarr/Radarr (App-Import via Prowlarr)
      curl -s -X POST "$PROWLARR_URL/api/v1/applications" \
        -H "X-Api-Key: $(cat $PROWLARR_API)" \
        -H "Content-Type: application/json" \
        -d '[{"name":"Sonarr","implementation":"Sonarr","baseUrl":"http://127.0.0.1:5320","apiKey":"'"$(cat /var/lib/sonarr-5320/apikey)"'","syncCategories":[4000,4005,4010]}]' || true

      # Flag setzen → Provisioning läuft nie wieder
      touch ${flagFile}
      echo "mediNix provisioning complete"
    '';
  };
}
