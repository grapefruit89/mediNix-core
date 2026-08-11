# ---
# id: "592-rollout"
# title: "Rollout Soft-Warnings (networking/firewall state checks)"
# domain: 50
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-0000
# provides: ["assertions"]
# requires: []
# ports: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# ---
{ config, lib, ... }:

let
  warn = message: { assertion = true; message = "WARN: ${message}"; };
in
{
  # Soft-Warnings: kein Build-Abbruch, nur Hinweis für Rollout-Sicherheit
  config.assertions = [
    (lib.optional (config.networking.firewall.enable == false)
      (warn "[mediNix-core/ROLLUP] networking.firewall.enable=false — Dienste sind ungefiltert erreichbar. Empfohlen: firewall.enable=true + 521-nftables Regeln."))
  ];
}
