# ---
# id: "598-observability-guardrails"
# title: "Observability & Monitoring Guardrails"
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
in
lib.mkIf cfg.enable {
  assertions = [
    # SEC-001: Crowdsec (Teil der 58er Observability)
    (reg.mkErrorDoc "SEC-001" !(cfg.observability.crowdsec.enable && cfg.observability.crowdsec.enrollKeyFile == null) "5820")
  ];
}
