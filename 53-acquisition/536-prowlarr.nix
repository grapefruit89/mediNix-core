# ---
# id: "536-prowlarr"
# title: "Prowlarr — Indexer Manager (53-acquisition, Service 536)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-11-26
# logo: https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/prowlarr.svg
# links:
#   adr: ADR-532, ADR-5050
# provides: []
# requires: ["53-acquisition/arr-module"]
# ---
# ─────────────────────────────────────────────────────────────────────────────
# ARCHITEKTUR-VORGABE: PROWLARR WIRD NICHT AN DEN VPN-KILLSWITCH GEBUNDEN!
# Prowlarr benötigt direkten WAN-Zugang und läuft bewusst über das Standard-Host-
# Netzwerk (ohne VPN). Der VPN-Killswitch ist ausschließlich für den Payload-
# Downloader (SABnzbd) reserviert.
# ─────────────────────────────────────────────────────────────────────────────
{
  config,
  lib,
  pkgs,
  ...
}:

import ./arr-module.nix { inherit lib config pkgs; } {
  name = "prowlarr";
  title = "Prowlarr";
  description = "Indexer-Proxy & Integration";
  binaryName = "Prowlarr";
  enableDescription = "Prowlarr Indexer Proxy";
  role = "indexer";
  apiVersion = "v1";
  ramBudget = "512M";
  allowedPeers = [ "sabnzbd" ];
  updateMechanism = "External";
  opsNotes = "Indexer-Proxy für Sonarr, Radarr, Lidarr und Readarr.";
}
