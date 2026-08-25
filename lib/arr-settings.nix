# ---
# id: "arr-settings"
# title: ".NET AppSettings → Environment Variables (declarative Arr config)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 2
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-5050
#   repo-harvest: mynixos (mkServarrSettingsEnvVars, vergessen), nixflix (gleiches Pattern)
# note: "ASP.NET Configuration: {APP}__{SECTION}__{KEY}=value (doppelter Unterstrich trennt Ebenen)"
# requires: []
# ---
{ lib }:

# Konvertiert ein verschachteltes Nix-Attrset in .NET Environment Variables.
# Alle Arr-Apps (Sonarr/Radarr/Readarr/Lidarr/Prowlarr/Jellyseerr) akzeptieren
# Konfiguration deklarativ via Umgebungsvariablen — ersetzt curl-Provisioning-Calls
# (keine Race-Conditions, idempotent, kein API-Timing-Problem).
#
# Beispiel:
#   mkSonarr { server.port = 5320; auth.method = "External"; }
#   → { SONARR__SERVER__PORT = "5320"; SONARR__AUTH__METHOD = "External"; }
#
# Schema: {APP}__{SECTION}__{KEY} = value  (lib.toUpper auf allen Pfad-Segmenten)
rec {
  # Rekursiv durch verschachtelte Attrsets iterieren.
  # Baut den VOLLEN Key inkl. Prefix (SONARR__SERVER__PORT), nicht nur den Suffix.
  mkArrEnv = prefix: settings:
    let
      go = path: val:
        if lib.isAttrs val
        then lib.concatMapAttrs (k: v: go (path ++ [ k ]) v) val
        else { "${prefix}__${lib.concatStringsSep "__" (map lib.toUpper path)}" = toString val; };
    in
      go [ ] settings;

  # Convenience-Wrapper für jeden Arr-Dienst (Prefix nach ASP.NET-Konvention)
  mkSonarr     = mkArrEnv "SONARR";
  mkRadarr     = mkArrEnv "RADARR";
  mkReadarr    = mkArrEnv "READARR";
  mkLidarr     = mkArrEnv "LIDARR";
  mkProwlarr   = mkArrEnv "PROWLARR";
  # Jellyseerr nutzt JELLYSEERR (nicht JELLYFIN — eigene App)
  mkJellyseerr = mkArrEnv "JELLYSEERR";
}
