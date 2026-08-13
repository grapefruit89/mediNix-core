# ---
# id: "591-ingress-guardrails"
# title: "Ingress & DNS Guardrails"
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
  servicesReg = import ../lib/registry.nix { inherit lib; };
in
lib.mkIf cfg.enable {
  assertions = [
    (reg.mkErrorDoc "TLS-001" !(cfg.ingress.tls.acmeHost != null && cfg.ingress.tls.certFile != null) "5111")
    (reg.mkErrorDoc "TLS-002" (cfg.ingress.tls.mode != "custom" || (cfg.ingress.tls.certFile != null && cfg.ingress.tls.keyFile != null)) "5111")
    (reg.mkErrorDoc "TLS-003" !(cfg.jellyfin.enable && cfg.ingress.tls.mode == "off") "5111")
    (reg.mkErrorDoc "AUTH-001" !(cfg.ingress.auth.mode == "forward-auth" && !cfg.authProxyPresent) "5120")

    # INV-INGRESS-01: Kein manueller Caddy-vHost außerhalb der Registry erlaubt.
    (reg.mkInvariant "INV-INGRESS-01"
      (let
        registryHosts = lib.mapAttrsToList
          (n: s: "${n}.${cfg.domain}")
          (lib.filterAttrs (_: s: s.caddyClass != "none") servicesReg.services);
        configHosts = lib.attrNames (config.services.caddy.virtualHosts or { });
      in
        lib.all (h: lib.elem h registryHosts || cfg.domain == "") configHosts))

    # POL-DNS-001: Verschlüsseltes DNS (DoT) muss aktiv sein
    (reg.mkInvariant "INV-DNS-01"
      (!config.services.resolved.enable || config.services.resolved.dnsovertls == "true" || config.services.resolved.dnsovertls == "opportunistic"))
  ];
}
