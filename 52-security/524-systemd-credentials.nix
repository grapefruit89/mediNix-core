# ---
# id: "524-systemd-credentials"
# title: "LoadCredentialEncrypted für alle cfg.secrets.* ApiKey-Files"
# domain: 52
# folder: 52-security
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5000
#   skill: nixos-context7-gate
# context7:
#   - query: "systemd service LoadCredentialEncrypted serviceConfig example credentials"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "systemd.services.<name>.serviceConfig.LoadCredential = [ \"name:path\" ];"
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  # Map: dienstname -> secret-pfad-option (nur wenn aktiviert + pfad gesetzt)
  secretMap = {
    sonarr      = cfg.services.sonarr.apiKeyFile or null;
    radarr      = cfg.services.radarr.apiKeyFile or null;
    prowlarr    = cfg.services.prowlarr.apiKeyFile or null;
    lidarr      = cfg.services.lidarr.apiKeyFile or null;
    readarr     = cfg.services.readarr.apiKeyFile or null;
    sabnzbd     = cfg.services.sabnzbd.apiKeyFile or null;
    jellyfin    = cfg.services.jellyfin.apiKeyFile or null;
    jellyseerr  = cfg.services.jellyseerr.apiKeyFile or null;
  };
  # Filtere: nur aktive Dienste mit gesetztem Pfad
  activeSecrets = lib.filterAttrs (name: path: path != null && (cfg.services.${name}.enable or false)) secretMap;
in
{
  # Für jeden aktiven Dienst mit ApiKeyFile: LoadCredentialEncrypted injizieren.
  # (Context7-verifiziert: serviceConfig.LoadCredential[Encrypted] = ["name:path"])
  config.systemd.services = lib.mapAttrs' (name: path:
    lib.nameValuePair "mediNix-${name}" {
      serviceConfig.LoadCredentialEncrypted = [ "${name}-api-key:${path}" ];
    }
  ) activeSecrets;
}
