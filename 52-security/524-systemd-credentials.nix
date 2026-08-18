# ---
# id: "524-systemd-credentials"
# title: "LoadCredentialEncrypted for all cfg.secrets.* ApiKey files"
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
  # Map: service name -> secret path option (only if enabled + path is set)
  # WARNING: Paths are under cfg.secrets.* (NOT cfg.services.<name>.apiKeyFile — doesn't exist!)
  # Jellyfin uses jellyfinAdminPasswordFile (not apiKeyFile).
  secretMap = {
    sonarr      = cfg.secrets.sonarrApiKeyFile or null;
    radarr      = cfg.secrets.radarrApiKeyFile or null;
    prowlarr    = cfg.secrets.prowlarrApiKeyFile or null;
    lidarr      = cfg.secrets.lidarrApiKeyFile or null;
    readarr     = cfg.secrets.readarrApiKeyFile or null;
    sabnzbd     = cfg.secrets.sabnzbdApiKeyFile or null;
    jellyfin    = cfg.secrets.jellyfinAdminPasswordFile or null;
    jellyseerr  = cfg.secrets.jellyseerrApiKeyFile or null;
  };
  # Filter: only active services with a set path
  # IMPORTANT: Unit names = plain kebab-case (sonarr.service, not mediNix-sonarr).
  # SSoT: lib/service-factory.nix builds systemd.services."${name}".
  # StateDirectory has the port (sonarr-5320), the Unit DOES NOT.
  activeSecrets = lib.filterAttrs (name: path: path != null && (cfg.services.${name}.enable or false)) secretMap;
in
{
  # For each active service with an ApiKeyFile: inject LoadCredentialEncrypted.
  # Unit = plain name (e.g., "sonarr"), NOT "mediNix-${name}" — otherwise it won't hit a real Unit.
  config.systemd.services = lib.mapAttrs' (name: path:
    lib.nameValuePair "${name}" {
      serviceConfig.LoadCredentialEncrypted = [ "${name}-api-key:${path}" ];
    }
  ) activeSecrets;
}
