# lib/wait-for-api.nix
#
# Erzeugt ein Shell-Skript, das vor Provisioning-Schritten auf die
# echte API-Readiness eines Dienstes wartet (bis zu timeoutSec Sekunden).
{ lib, pkgs }:

{
  baseUrl,
  statusPath ? "/system/status",
  secretFile ? null,
  apiKeyHeader ? "X-Api-Key",
  timeoutSec ? 90,
  description ? "API",
}:

let
  mkSecureCurl = import ./mk-secure-curl.nix { inherit lib pkgs; };
  checkCmd = mkSecureCurl {
    inherit secretFile apiKeyHeader;
    url = "${baseUrl}${statusPath}";
    method = "GET";
    extraArgs = "-sf";
    silent = true;
  };
in
pkgs.writeShellScript "wait-for-${lib.strings.sanitizeDerivationName description}" ''
  set -euo pipefail

  echo "Warte auf Readiness von ${description} (${baseUrl}${statusPath})..."
  for ((i = 1; i <= ${toString timeoutSec}; i++)); do
    if ${checkCmd} >/dev/null 2>&1; then
      echo "[OK] ${description} ist bereit nach $i Sekunden."
      exit 0
    fi
    ${pkgs.coreutils}/bin/sleep 1
  done

  echo "[FATAL] ${description} an ${baseUrl}${statusPath} antwortet nach ${toString timeoutSec}s nicht!" >&2
  exit 1
''
