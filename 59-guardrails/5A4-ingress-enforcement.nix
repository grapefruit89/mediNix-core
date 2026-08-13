# ---
# id: "5A4-ingress-enforcement"
# title: "Ingress Enforcement — alle Caddy-vHosts müssen in Registry definiert sein"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-08-12
# links:
#   adr: ADR-0000 §5 (Chameleon Caddy), ADR-0000 (Dezimalrahmen)
#   repo-harvest: NixmitGROK (ingress-enforcement pattern)
# context7:
#   - query: "services.caddy virtualHosts configuration"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "services.caddy.virtualHosts.<host> = { ... } (valid Caddy vHost def)"
# ---
{ config, lib, ... }:

let
  cfg = config.grapefruitMedia;
  reg = import ./590-registry.nix { inherit lib; };
  servicesReg = import ../lib/registry.nix { inherit lib; };
in
lib.mkIf cfg.enable {
  assertions = [
    # INV-INGRESS-01: Kein manueller Caddy-vHost außerhalb der Registry erlaubt.
    # Alle Dienste müssen in lib/registry.nix definiert sein (caddyClass != "none").
    (reg.mkInvariant "INV-INGRESS-01"
      (let
        # Alle Registry-Hosts die einen Caddy-vHost bekommen (caddyClass != none)
        registryHosts = lib.mapAttrsToList
          (n: s: "${n}.${cfg.domain}")
          (lib.filterAttrs (_: s: s.caddyClass != "none") servicesReg.services);
        # Alle aktuell konfigurierten Caddy-vHosts
        configHosts = lib.attrNames (config.services.caddy.virtualHosts or { });
      in
        # Jeder konfigurierte vHost MUSS in der Registry sein (oder domain leer = kein Ingress)
        lib.all (h: lib.elem h registryHosts || cfg.domain == "") configHosts))
  ];
}
