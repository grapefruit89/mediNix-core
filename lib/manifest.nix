# ---
# id: "manifest"
# title: "Manifest-Schema & Service-Contract Helper (SSoT)"
# domain: 50
# folder: "lib"
# status: active
# complexity: 2
# last_reviewed: 2026-10-26
# links:
#   adr: ADR-0010, ADR-0000
# ---
# lib/manifest.nix
#
# SSoT-Hilfsfunktionen und Schema-Vertrag fuer mediNix-Dienst-Manifeste (ADR-0010).
# Formalisiert das Schema v1 und bietet den typisierten Generator mkManifestEntry.
{ lib }:

let
  schemaVersion = 1;

  accessGroups = [
    "stream"
    "internal"
    "public"
    "idp"
    "none"
  ];

  monitoringTypes = [
    "http"
    "tcp"
    "systemd"
    "none"
  ];

  metricsTypes = [
    "exportarr"
    "native"
    "none"
  ];

  uiGroups = [
    "Media"
    "Acquisition"
    "Transfer"
    "Observability"
    "Security"
  ];

  opsPriorities = [
    "low"
    "medium"
    "high"
  ];

  arrRoles = [
    "none"
    "media-manager"
    "indexer"
    "downloader"
  ];

  # mkManifestEntry:
  # Erzeugt einen vollstaendigen, schema-validierten Dienst-Steckbrief fuer config.medinix.manifest.<name>.
  # Validiert essentielle Invarianten (num 500..599, Slot-0-Schutz, accessGroup) zur Eval-Zeit per Assertion.
  mkManifestEntry =
    {
      name,
      num,
      accessGroup,
      enable ? true,
      hasDaemon ? true,
      ui ? { },
      monitoring ? { },
      metrics ? { },
      ops ? { },
      arr ? { },
      sources ? { },
      allowUnauthenticated ? false,
      unauthenticatedPaths ? [ ],
      customConfig ? "",
      role ? null,
      capabilities ? [ ],
      extraGroups ? [ ],
      needsSharedGroup ? null,
      needsMediaGroup ? null,
    }:
    assert (
      lib.assertMsg (
        num >= 500 && num <= 599
      ) "mkManifestEntry [${name}]: num muss zwischen 500 und 599 liegen (ADR-0000), gegeben: ${toString num}"
    );
    assert (
      lib.assertMsg ((num - (num / 10) * 10) != 0 || !hasDaemon)
        "mkManifestEntry [${name}]: Slot 0 (num=${toString num}) ist fuer Ordner/Engines reserviert und darf keinen Daemon tragen (ADR-0000 §2)"
    );
    assert (
      lib.assertMsg (lib.elem accessGroup accessGroups)
        "mkManifestEntry [${name}]: ungueltige accessGroup '${accessGroup}'! Erlaubt: ${lib.concatStringsSep ", " accessGroups}"
    );
    {
      inherit
        schemaVersion
        enable
        hasDaemon
        num
        accessGroup
        allowUnauthenticated
        unauthenticatedPaths
        customConfig
        role
        capabilities
        extraGroups
        needsSharedGroup
        needsMediaGroup
        ;

      ui = {
        title = name;
        description = "";
        icon = name;
        group = "Media";
        showOnLanding = true;
      } // ui;

      monitoring = {
        inherit enable;
        type = "http";
        healthPath = null;
        expectedStatus = 200;
      } // monitoring;

      metrics = {
        inherit enable;
        type = "none";
      } // metrics;

      ops = {
        priority = "medium";
        ramBudget = "";
        notes = "";
      } // ops;

      arr = {
        role = "none";
        category = name;
        apiVersion = "v3";
      } // arr;

      sources = {
        upstream = null;
        repo = null;
        nixos = null;
        nixpkgsTest = null;
        api = null;
      } // sources;
    };
in
{
  inherit
    schemaVersion
    accessGroups
    monitoringTypes
    metricsTypes
    uiGroups
    opsPriorities
    arrRoles
    mkManifestEntry
    ;
}
