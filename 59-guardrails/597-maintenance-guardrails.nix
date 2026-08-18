# ---
# id: "597-maintenance-guardrails"
# title: "Maintenance & Backup Guardrails"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-13
# links:
#   adr: ADR-5043
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  reg = import ./590-registry.nix { inherit lib; };
  # Alle State-Dirs die für Backup freigegeben sind (read-only)
  # Generiert primär dynamisch aus der Registry, plus manuelle Ausnahmen (ntfy-sh, recyclarr)
  registry = import ../lib/registry.nix { inherit lib; };
  registryDirs = lib.mapAttrsToList
    (_: svc: "/var/lib/${svc.name}")
    registry.services;
  stateDirs = registryDirs ++ [ "/var/lib/ntfy-sh-5810" "/var/lib/recyclarr-5600" ];
in
lib.mkIf cfg.enable {
  assertions = [
    # STORE-003: sqlite.backup path muss outside of /nix/store sein
    (reg.mkErrorDoc "STORE-003"
      (let backupPath = cfg.maintenance.sqlite.backupDir;
       in !(lib.hasPrefix "/nix/store" backupPath))
      "5720")
  ];

}
