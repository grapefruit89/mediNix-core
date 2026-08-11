# ---
# id: "591-assertions"
# title: "mediNix-core Config Assertions (fail-closed guardrails)"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-0000, ADR-5043
# provides: ["assertions"]
# requires: []
# ports: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  ing = cfg.ingress;
  must = assertion: message: { inherit assertion message; };
in
{
  # Assertions: Build bricht ab, statt stillschweigend falsch zu konfigurieren.
  config.assertions =
    [
      # TLS: acmeHost und certFile schließen sich aus (beide = doppelte Quelle)
      (must (!(ing.tls.acmeHost != null && ing.tls.certFile != null))
        "[mediNix-core/TLS] Entweder ingress.tls.acmeHost ODER ingress.tls.certFile setzen, nicht beides.")

      # TLS: Wenn acmeHost gesetzt, MUSS der Host security.acme konfiguriert haben
      (must (!(ing.tls.acmeHost != null && !config.security.acme.certs ? ${ing.tls.acmeHost or ""}))
        "[mediNix-core/TLS] acmeHost='${ing.tls.acmeHost or "null"}' gesetzt, aber security.acme hat kein Zertifikat dafür. Host muss security.acme konfigurieren (DNS-01 via Cloudflare).")

      # Internal-Klasse braucht LAN-only: kein WAN-Exposure erlaubt
      (must (!(cfg.caddyClassInternalWan or false))
        "[mediNix-core/INGRESS] Internal-Dienste dürfen nicht WAN-exposed sein (siehe ADR-5110).")
    ]
    ++ lib.optionals cfg.services.sonarr.enable [
      # .NET-EOL-Warnung (aus Harvester #7442): wenn nixpkgs eine EOL-.NET nutzt,
      # braucht Sonarr ggf. permittedInsecurePackages. Host-Entscheidung, kein Modul-Default.
      (must (lib.versionAtLeast (lib.getVersion pkgs.dotnetRuntime or "0") "8.0"
            || config.nixpkgs.config.permittedInsecurePackages or [] != [])
        "[mediNix-core/SONARR] Sonarr läuft auf .NET. Wenn nixpkgs eine EOL-.NET-Version (6.0.x) nutzt, setze nixpkgs.config.permittedInsecurePackages = [\"aspnetcore-runtime-wrapped-6.0.x\"]. Host-Entscheidung — nicht im Modul hardcoded.")
    ];
}
