# ---
# id: "ingress-access"
# title: "Ein Produzent fuer die effektive vHost-Exposure (Vhost-Override gewinnt)"
# domain: 51
# folder: "lib"
# status: active
# complexity: 1
# last_reviewed: 2026-10-17
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
    cfg.ingress.vhosts.${n}.accessGroup or m.accessGroup or "none";

  # WAN-sichtbare Gruppen (511 Rendering, 513 DNS).
  wanGroups = [
    "public"
    "stream"
    "idp"
  ];

  isWan = g: lib.elem g wanGroups;
}
