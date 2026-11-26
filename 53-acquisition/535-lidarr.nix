# ---
# id: "535-lidarr"
# title: "Lidarr — Music Download Manager (53-acquisition, Service 535)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-11-26
# logo: https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/lidarr.svg
# links:
#   adr: ADR-532, ADR-5050
# provides: []
# requires: ["53-acquisition/arr-module"]
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

import ./arr-module.nix { inherit lib config pkgs; } {
  name = "lidarr";
  title = "Lidarr";
  description = "Musik-Verwaltung & Automatisierung";
  binaryName = "Lidarr";
  enableDescription = "Lidarr Music Download Manager";
  category = "music";
  apiVersion = "v1";
  ramBudget = "1G";
  opsNotes = "Arr-Musik-Management mit Prowlarr- und SABnzbd-Kopplung.";
}
