# ---
# id: "533-radarr"
# title: "Radarr — Movie Management (53-acquisition, Service 533)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-11-26
# logo: https://cdn.jsdelivr.net/gh/grapefruit89/logorepo@main/logos/radarr.svg
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
  name = "radarr";
  title = "Radarr";
  description = "Filme-Verwaltung & Automatisierung";
  binaryName = "Radarr";
  enableDescription = "Radarr Movies Manager";
  category = "movies";
  ramBudget = "1.5G";
  opsNotes = "Arr-Filme-Management mit Prowlarr- und SABnzbd-Kopplung.";
  extraOptions = {
    rootFolder = lib.mkOption {
      type = lib.types.str;
      default = config.medinix.storage.mediaRoot + "/movies";
      description = "Arr root folder (API-configured via provisioning).";
    };
    qualityProfile = lib.mkOption {
      type = lib.types.str;
      default = "HD-1080p";
      description = "Arr quality profile name (API-configured via provisioning).";
    };
  };
}
