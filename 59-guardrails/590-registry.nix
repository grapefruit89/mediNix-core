# ---
# id: "590-registry"
# title: "Zentrale Fehler-Registry (Invarianten + Assertion-Errors)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-0000 (Dezimalrahmen-Verfassung)
#   skill: nixos-context7-gate
# ---
# lib-ähnliche Datei — KEIN NixOS-Modul, nur Daten + Helper.
# Invarianten = Systemgarantien (immer wahr, Architektur-Level).
# Errors = konfigurationsabhängige User-Fehler.
{ lib }:

let
  # Invarianten: Systemgarantien die zu JEDER Zeit gelten müssen.
  # Verletzung = Architektur-Verletzung, nicht Konfigurationsfehler.
  invariants = {
    "INV-01" = "Port = ServiceNumber × 10. Verletzung bedeutet Dezimalrahmen-Bruch.";
    "INV-02" = "Alle Dienste binden auf 127.0.0.1. Niemals 0.0.0.0 im WAN.";
    "INV-03" = "GID 5000 = media. Kein Dienst nutzt eine andere Media-GID.";
    "INV-04" = "usenet-confinement aktiv → vpn.interface ≠ \"\" und vpn.dns ≠ [].";
    "INV-05" = "Kein Secret liegt im Nix-Store (/nix/store/).";
    "INV-06" = "stream-Dienste sind niemals ohne TLS WAN-erreichbar.";
    "INV-07" = "Kein Dienst mit /dev/dri-Bedarf hat PrivateDevices = true.";
  };

  # Errors: konfigurationsabhängige Fehler (User hat was falsch gesetzt).
  errors = {
    "VPN-001" = "vpn.interface ist leer — kein UID-Routing möglich.";
    "VPN-002" = "vpn.dnsServers ist leer — DNS-Leak durch Host-Resolver möglich.";
    "VPN-003" = "usenet-confinement aktiv aber weder sabnzbd noch prowlarr enabled.";
    "VPN-005" = "vpn.wgConf liegt im Nix-Store — private Key ist world-readable.";
    "TLS-001" = "tls.acmeHost und tls.certFile beide gesetzt — nur eines erlaubt.";
    "TLS-002" = "tls.mode = custom aber certFile oder keyFile fehlt.";
    "TLS-003" = "stream-Dienste aktiv aber tls.mode = off — kein TLS für WAN.";
    "AUTH-001" = "ingress.auth.mode = forward-auth aber authProxyPresent = false.";
    "DNS-001" = "DDNS aktiv aber kein Token konfiguriert.";
    "SEC-001" = "CrowdSec aktiv aber enrollKeyFile fehlt.";
    "SEC-002" = "networking.firewall.enable = false — nftables-Regeln greifen nicht.";
    "STORE-001" = "storage.mediaRoot ist leer.";
    "STORE-002" = "storage.metadataDir liegt auf HDD — SSD empfohlen.";
  };

  # Helper: Invariante (Präfix INVARIANTE, ADR-0000 Hinweis)
  mkInvariant = code: condition: {
    assertion = condition;
    message = "[mediNix-core/INVARIANTE/${code}] ${invariants.${code}}\n"
            + "  Dies ist keine Konfigurationsoption — es ist eine Systemgarantie.\n"
            + "  → ADR-0000 Dezimalrahmen-Verfassung";
  };

  # Helper: Error (Präfix CODE, domänen-spezifischer ADR-Link via withDoc)
  mkError = code: condition: {
    assertion = condition;
    message = "[mediNix-core/${code}] ${errors.${code}}";
  };

  # Helper: Error mit ADR-Dokumentations-Link
  mkErrorDoc = code: condition: adr: {
    assertion = condition;
    message = "[mediNix-core/${code}] ${errors.${code}}\n  → docs/ADR-${adr}.md";
  };
in
{
  inherit invariants errors mkInvariant mkError mkErrorDoc;
}
