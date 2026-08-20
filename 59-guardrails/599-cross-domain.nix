# ---
# id: "599-cross-domain"
# title: "Cross-Domain Guardrails (Phase 3)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-08-19
# links:
#   adr: ADR-0000, ADR-5043
# ---
#
# Guards that span multiple domains — things that can't be checked locally
# within a single module but emerge from the interaction of several.
#
# BIND-001 : No mediNix service port must appear in networking.firewall.allowedTCPPorts.
#            All services bind on 127.0.0.1 and are exposed exclusively via Caddy.
#            A port in allowedTCPPorts means the service is WAN-reachable without TLS/auth.
#
# VPN-010  : usenet-confinement.enable → sabnzbd killswitch instance active.
#            (525-usenet-confinement sets this automatically; assertion is a belt-and-braces
#             check that the cross-module wiring wasn't broken.)
#
# VPN-011  : usenet-confinement.enable ∧ prowlarr.enable → prowlarr killswitch active.
#            Prowlarr and SABnzbd share the VPN sandbox; if one leaks, both are compromised.
{ config, lib, ... }:

let
  cfg      = config.grapefruitMedia;
  reg      = import ./590-registry.nix { inherit lib; };
  svcReg   = import ../lib/registry.nix { inherit lib; };

  # Collect all ports from the registry that belong to enabled services.
  # We only warn about ports whose service is actually enabled.
  mediNixPorts =
    lib.mapAttrsToList (_: svc: svc.port)
      (lib.filterAttrs (_: svc:
        svc.port != null &&
        (cfg.${svc.name}.enable or false)
      ) svcReg.services);

  allowedTCP = config.networking.firewall.allowedTCPPorts or [];

  # Ports that should be internal but are exposed in the host firewall
  leakingPorts = lib.filter (p: lib.elem p allowedTCP) mediNixPorts;
in
lib.mkIf cfg.enable {
  assertions = [
    # BIND-001: No mediNix service port is directly WAN-reachable via host firewall.
    # All traffic must pass through Caddy (TLS termination + optional forward-auth).
    (reg.mkInvariant "BIND-001"
      (leakingPorts == []))

    # VPN-010: When usenet-confinement is active, SABnzbd must be under killswitch.
    # (525-usenet-confinement.nix creates this instance — this assertion verifies the
    #  wiring is intact so a module refactor can't silently remove the protection.)
    (reg.mkErrorDoc "VPN-010"
      (cfg.usenet-confinement.enable ->
        let
          inst = config.services.vpnKillSwitch.instances.sabnzbd or null;
          regUid = svcReg.services.sabnzbd.uid;
        in
          inst != null
          && inst.enable
          && inst.uid == regUid)
      "5410")

    # VPN-011: When usenet-confinement is active AND Prowlarr is enabled,
    # Prowlarr must also be under killswitch (IP-leak prevention).
    (reg.mkErrorDoc "VPN-011"
      (cfg.usenet-confinement.enable && cfg.prowlarr.enable ->
        let
          inst = config.services.vpnKillSwitch.instances.prowlarr or null;
          regUid = svcReg.services.prowlarr.uid;
        in
          inst != null
          && inst.enable
          && inst.uid == regUid)
      "5410")
  ];
}
