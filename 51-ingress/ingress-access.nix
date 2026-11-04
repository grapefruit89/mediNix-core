# ---
# id: "ingress-access"
# title: "Ein Produzent fuer die effektive vHost-Exposure (Vhost-Override gewinnt)"
# domain: 51
# folder: 51-ingress
# status: active
# kind: library
# complexity: 1
# last_reviewed: 2026-11-03
# provides: ["ingress-access", "51-ingress/ingress-access"]
# requires: []
# links:
#   adr: ADR-511
# ---
# SSOT fuer die effektive `accessGroup` eines vHosts: der Vhost-Override
# (`ingress.vhosts.<name>.accessGroup`) gewinnt, sonst das Manifest.
#
# 511 (Rendering), 513 (DNS) und 518 (Tiles) importieren DIESE Funktion.
# Vorher lasen 513 und 518 das Manifest direkt, waehrend 511 schon aufloeste —
# der Override divergierte dadurch still:
#   accessGroup = "none"   -> 511 rendert keinen vHost, aber 513 publizierte
#                             trotzdem einen Cloudflare-Record (attrNames vhosts
#                             war ungefiltert) und 518 zeigte kein Tile.
#   accessGroup = "public" -> 511 rendert WAN + forward_auth, aber 513 legte
#                             keinen Record an und 518 zeigte kein Tile.
# Der Import ist eine reine Funktion (kein NixOS-Modul), daher keine Kante
# zwischen den Modulen.
{ lib }:
rec {
  accessGroupOf =
    cfg: n: m:
    let
      # `accessGroup` hat einen Default (null) — ein Vhost-Eintrag OHNE
      # accessGroup (z. B. nur `landing = true`) ist deshalb kein
      # "accessed but has no value defined"-Fehler mehr. `or` faengt diesen
      # Modulsystem-Fehler NICHT: die Option ist deklariert, nur ohne Wert.
      override = cfg.ingress.vhosts.${n}.accessGroup or null;
    in
    if override != null then override else (m.accessGroup or "none");

  # WAN-sichtbare Gruppen (511 Rendering, 513 DNS).
  wanGroups = [
    "public"
    "stream"
    "idp"
  ];

  isWan = g: lib.elem g wanGroups;

  # Laeuft 511 in der Host-Caddy (`global`) oder als eigene `caddy-media`-Unit
  # (`standalone`)? `auto` entscheidet anhand von `services.caddy.enable`.
  #
  # Diese Frage brauchen mehrere Module: 511 (Rendering), 516 (aus welcher Unit
  # liest CrowdSec die Access-Logs?) und 519 (Guardrails). Vorher stand die Logik
  # nur in 511, und 516 hatte `caddy-media.service` hartkodiert — im
  # Global-Modus las CrowdSec damit ins Leere (stiller Blindflug, keine
  # Assertion). `caddyEnabled` bleibt Parameter, damit diese Datei eine reine
  # Funktion ohne NixOS-Kante bleibt.
  # Ref: Review 2026-10-17, Finding 13.
  useGlobalOf =
    mode: caddyEnabled:
    if mode == "global" then
      true
    else if mode == "standalone" then
      false
    else
      caddyEnabled;

  # Unit-Name der Caddy-Instanz, aus der 516 die Access-Logs liest.
  caddyUnitOf =
    mode: caddyEnabled:
    if useGlobalOf mode caddyEnabled then "caddy.service" else "caddy-media.service";

  # Ist TLS ueberhaupt aktiv? `acmeHost` holt Zertifikate, `custom` bringt eigene
  # Dateien mit, `internal` braucht den Secure Context (Passkeys, Clipboard).
  # Eine Quelle fuer 511 (Rendering) und 518 (Link-Schema) statt zweier Kopien.
  # Ref: Review 2026-10-17, Finding 26.
  tlsEnabledOf =
    ing: ing.tls.acmeHost != null || ing.tls.mode == "custom" || ing.tls.mode == "internal";

  # Semantische CIDR-Validierung (D-14-02):
  # Prueft, ob ein gegebener CIDR-String syntaktisch und semantisch in private
  # IP-Bereiche faellt (RFC 1918, RFC 6598 CGNAT, RFC 4193 ULA, Loopback, Link-Local)
  # und weder zu weite Praefixe (v4 < /8, v6 < /7) noch fehlerhafte Grenzen enthaelt.
  isPrivateCidr =
    c:
    let
      prefix = lib.toInt (lib.last (lib.splitString "/" c));
      minPrefix = if lib.hasInfix ":" c then 7 else 8;
      maxPrefix = if lib.hasInfix ":" c then 128 else 32;
    in
    builtins.match "(10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|127\\.|169\\.254\\.|100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.|[fF][cCdD][0-9A-Fa-f]{2}:|[fF][eE]80:|::1/).*" c
    != null
    && prefix >= minPrefix
    && prefix <= maxPrefix;
}
