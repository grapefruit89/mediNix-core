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
  # ACHTUNG: Pfade liegen unter cfg.secrets.* (NICHT cfg.services.<name>.apiKeyFile — gibt's nicht!)
  # Jellyfin nutzt jellyfinAdminPasswordFile (kein apiKeyFile).
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
  # Filtere: nur aktive Dienste mit gesetztem Pfad
  # WICHTIG: Unit-Namen = plain kebab-case (sonarr.service, nicht mediNix-sonarr).
  # SSoT: lib/service-factory.nix Zeile 47 baut systemd.services."${name}".
  # StateDirectory hat den Port (sonarr-5320), die Unit NICHT.
  activeSecrets = lib.filterAttrs (name: path: path != null && (cfg.services.${name}.enable or false)) secretMap;
in
{
  # Für jeden aktiven Dienst mit ApiKeyFile: LoadCredentialEncrypted injizieren.
  # Unit = plain name (z.B. "sonarr"), NICHT "mediNix-${name}" — sonst trifft es keine echte Unit.
  config.systemd.services = lib.mapAttrs' (name: path:
    lib.nameValuePair "${name}" {
      serviceConfig.LoadCredentialEncrypted = [ "${name}-api-key:${path}" ];
    }
  ) activeSecrets;
}
