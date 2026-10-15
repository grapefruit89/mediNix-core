# ---
# id: "arr-settings-template"
# title: "arr-Settings als .NET-Env-Variablen (Template)"
# domain: 50
# folder: "docs/agents/07-patterns-misc/nixos-dotnet-env-config/templates"
# status: active
# complexity: 2
# last_reviewed: 2026-10-15
# links:
#   adr: ADR-0000
# ---

# ─────────────────────────────────────────────────────────────────────────────
# BEISPIEL-SNAPSHOT — NICHT weiterentwickeln (Korridor AB-027).
# Kanonische Quelle: /home/moritz/repos/mediNix-core/lib/arr-settings.nix
# Dieses Template driftet zwangslaeufig (gemessen 2026-10-15: 38 vs 50 Zeilen).
# Fuer echte Aenderungen immer lib/arr-settings.nix bearbeiten.
# ─────────────────────────────────────────────────────────────────────────────
# lib/arr-settings.nix — .NET AppSettings → Environment Variables
# Drop into lib/ and import from each Arr module:
#   arrSettings = import ../lib/arr-settings.nix { inherit lib; };
#   environment = arrSettings.mkSonarr { server.port = 5320; ... };
#
# CORRECT (no double-prefix bug): leaf builds full key incl. prefix.
{ lib }:
rec {
  mkArrEnv =
    prefix: settings:
    let
      go =
        path: val:
        if lib.isAttrs val then
          lib.concatMapAttrs (k: v: go (path ++ [ k ]) v) val
        else
          { "${prefix}__${lib.concatStringsSep "__" (map lib.toUpper path)}" = toString val; };
    in
    go [ ] settings;

  mkSonarr = mkArrEnv "SONARR";
  mkRadarr = mkArrEnv "RADARR";
  mkReadarr = mkArrEnv "READARR";
  mkLidarr = mkArrEnv "LIDARR";
  mkProwlarr = mkArrEnv "PROWLARR";
  mkSeerr = mkArrEnv "SEERR";
}
