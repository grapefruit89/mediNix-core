# ---
# id: "mk-secure-curl"
# title: "Secure-curl-Aufruf mit Timeouts"
# domain: 50
# folder: "lib"
# status: draft
# complexity: 2
# last_reviewed: 2026-10-15
# links:
#   adr: ADR-0000
# ---
# NIE VERDRAHTET (Entscheidung 2026-10-15) - aber mit echtem Anwendungsfall:
# 513-cloudflare-dns.nix uebergibt den Token als `-H "Authorization: Bearer $TOKEN"`
# und damit in argv. Dieses Modul nutzt curl `--variable secret@file` (>= 8.3).
# Siehe ROADMAP (P2).
# lib/mk-secure-curl.nix
#
# Generiert einen curl-Aufruf, der Secrets zur Laufzeit intern expandiert,
# statt sie als Klartext-Argument in argv / /proc/<pid>/cmdline zu leaken.
{ lib, pkgs }:

{
  # Pfad zur Datei, die das Secret enthält (z. B. "/run/credentials/sonarr.service/apiKey")
  secretFile ? null,
  apiKeyHeader ? "X-Api-Key",
  url,
  method ? "GET",
  headers ? { },
  data ? null,
  extraArgs ? "-sf",
  silent ? true,
}:

let
  baseArgs = lib.optionalString silent "-s";
  methodArg = lib.optionalString (method != "GET") "-X ${method}";

  # Native Parameter-Expansion von cURL (ab curl 8.3+)
  varArg = lib.optionalString (
    secretFile != null
  ) "--variable secret@${lib.escapeShellArg (toString secretFile)}";
  headerArg = lib.optionalString (
    secretFile != null
  ) ''--expand-header "${apiKeyHeader}: {{secret:trim}}"'';

  otherHeaderArgs = lib.concatStringsSep " " (
    lib.mapAttrsToList (name: value: ''--header "${name}: ${value}"'') headers
  );

  dataArg =
    if data == null then
      ""
    else if lib.hasPrefix "@" data then
      "--data-binary ${data}"
    else
      "--data-binary ${lib.escapeShellArg data}";
in
"${pkgs.curl}/bin/curl ${baseArgs} ${extraArgs} ${methodArg} ${varArg} ${headerArg} ${otherHeaderArgs} ${dataArg} ${lib.escapeShellArg url}"
