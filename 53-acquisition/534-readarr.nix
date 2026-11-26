# ---
# id: "534-readarr"
# title: "Readarr — Book Management (53-acquisition, Service 534)"
# domain: 53
# folder: 53-acquisition
# status: active
# complexity: 3
# last_reviewed: 2026-11-26
# logo: none — not in grapefruit89/logorepo yet
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
  name = "readarr";
  title = "Readarr";
  description = "Bücher- & Hörbuch-Verwaltung";
  binaryName = "Readarr";
  enableDescription = "Readarr Books Manager";
  category = "books";
  apiVersion = "v1";
  ramBudget = "1G";
  opsNotes = "Arr-Book-Management mit Prowlarr- und SABnzbd-Kopplung.";
}
