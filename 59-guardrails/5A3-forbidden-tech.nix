# ---
# id: "5A3-forbidden-tech"
# title: "Forbidden Technology Guardrails (Build-Time Enforcement of NO-CONTAINERS.md)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-0000 §5 (systemd-native), NO-CONTAINERS.md
#   repo-harvest: NixmitGROK (forbidden-tech pattern)
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  reg = import ./590-registry.nix { inherit lib; };
in
lib.mkIf cfg.enable {
  assertions = [
    # INV-TECH-01..03: verbotene Technologien strukturell unmöglich machen
    # (NO-CONTAINERS.md wird dadurch Build-zeitlich durchgesetzt, nicht nur dokumentiert)
    (reg.mkInvariant "INV-TECH-01" (!config.virtualisation.docker.enable))
    (reg.mkInvariant "INV-TECH-02" (!config.virtualisation.podman.enable))
    (reg.mkInvariant "INV-TECH-03" (!config.services.cron.enable))
  ];
}
