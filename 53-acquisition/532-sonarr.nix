# ---
# id: "532-sonarr"
# title: "Sonarr — Series Management (53-acquisition, Service 532)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-11-26
# anchors: ["twelve-factor-app", "least-privilege"]
# logo: https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/sonarr.svg
# provides: []
# requires: ["53-acquisition/arr-module"]
# links:
#   adr: ADR-532
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

import ./arr-module.nix { inherit lib config pkgs; } {
  name = "sonarr";
  title = "Sonarr";
  description = "Serien-Verwaltung & Automatisierung";
  binaryName = "Sonarr";
  enableDescription = "Sonarr TV Series Manager";
  category = "tv";
  ramBudget = "1.5G";
  opsNotes = "Arr-Serien-Management mit Prowlarr- und SABnzbd-Kopplung.";
  extraOptions = {
    rootFolder = lib.mkOption {
      type = lib.types.str;
      default = config.medinix.storage.mediaRoot + "/series";
      description = "Arr root folder (API-configured via provisioning).";
    };
    qualityProfile = lib.mkOption {
      type = lib.types.str;
      default = "HD-1080p";
      description = "Arr quality profile name (API-configured via provisioning).";
    };
  };
}
