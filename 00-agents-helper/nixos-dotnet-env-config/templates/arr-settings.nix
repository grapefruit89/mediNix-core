# lib/arr-settings.nix — .NET AppSettings → Environment Variables
# Drop into lib/ and import from each Arr module:
#   arrSettings = import ../lib/arr-settings.nix { inherit lib; };
#   environment = arrSettings.mkSonarr { server.port = 5320; ... };
#
# CORRECT (no double-prefix bug): leaf builds full key incl. prefix.
{ lib }:
rec {
  mkArrEnv = prefix: settings:
    let
      go = path: val:
        if lib.isAttrs val
        then lib.concatMapAttrs (k: v: go (path ++ [ k ]) v) val
        else { "${prefix}__${lib.concatStringsSep "__" (map lib.toUpper path)}" = toString val; };
    in
      go [ ] settings;

  mkSonarr     = mkArrEnv "SONARR";
  mkRadarr     = mkArrEnv "RADARR";
  mkReadarr    = mkArrEnv "READARR";
  mkLidarr     = mkArrEnv "LIDARR";
  mkProwlarr   = mkArrEnv "PROWLARR";
  mkJellyseerr = mkArrEnv "JELLYSEERR";
}
