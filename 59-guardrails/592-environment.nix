# ---
# id: "592-environment"
# title: "592-environment module"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-08-25
# links: 
# provides: []
# requires: ["lib/registry"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---
{ config, lib, ... }:

let
  cfg = config.medinix;
  svcReg = import ../lib/registry.nix { inherit lib; };
  hasFileSystem = path: builtins.hasAttr path config.fileSystems;

  mediNixPorts = lib.mapAttrsToList (_: svc: svc.port)
    (lib.filterAttrs (_: svc: svc.port != null && (cfg.${svc.name}.enable or false)) svcReg.services);
  allowedTCP = config.networking.firewall.allowedTCPPorts or [];
  leakingPorts = lib.filter (p: lib.elem p allowedTCP) mediNixPorts;

in lib.mkIf cfg.enable {
  assertions = [
    {
      assertion = leakingPorts == [];
      message = ''
        [mediNix] The following service ports are exposed in the host firewall (allowedTCPPorts): ${toString leakingPorts}
        
        [AI/Admin Context]
        Reason: All mediNix services bind strictly to 127.0.0.1 and must be exposed exclusively via the Caddy reverse proxy. 
        Exposing them directly in the host firewall bypasses TLS encryption and central Authentication guardrails.
        Ref: ADR-5043 (Network Isolation & Zero-Trust Localhost)
        Fix: Remove these ports from `networking.firewall.allowedTCPPorts`.
      '';
    }
    {
      assertion = cfg.hostIntegration.reverseProxy == "external" -> config.services.caddy.enable;
      message = ''
        [mediNix] hostIntegration.reverseProxy is set to "external", but services.caddy.enable is false!
        
        [AI/Admin Context]
        Reason: mediNix uses a Tri-State boundary model (managed/external/off). When set to external, mediNix injects virtualHosts additively, assuming the Host OS provides the running Caddy daemon.
        Ref: Architecture Boundary (Publish-Don't-Apply)
        Fix: Add `services.caddy.enable = true;` to the host configuration, or set `medinix.hostIntegration.reverseProxy = "managed";`.
      '';
    }
    {
      assertion = cfg.hostIntegration.nftables == "external" -> config.networking.nftables.enable;
      message = ''
        [mediNix] hostIntegration.nftables is set to "external", but networking.nftables.enable is false!
        
        [AI/Admin Context]
        Reason: mediNix injects its killswitch rules additively into nftables. Since it's set to external, the Host OS must enable the nftables engine.
        Ref: Architecture Boundary (Publish-Don't-Apply)
        Fix: Add `networking.nftables.enable = true;` to the host configuration, or set `medinix.hostIntegration.nftables = "managed";`.
      '';
    }
    {
      assertion = (cfg.hostIntegration.storage == "external" && cfg.storage.backends ? hot && cfg.storage.backends ? cold) -> 
        (hasFileSystem "${cfg.storage.mediaRoot}/media/movies" || hasFileSystem "${cfg.storage.mediaRoot}/media/tv");
      message = ''
        [mediNix] hostIntegration.storage is set to "external", but the required mergerfs mountpoints are missing from `fileSystems`!
        
        [AI/Admin Context]
        Reason: Storage is set to external, meaning mediNix will not create the MergerFS pools itself. The Host must provide the final mountpoints (e.g. /srv/media/media/movies) in its hardware configuration.
        Ref: ADR-5710 (Storage Tiering & Boundary)
        Fix: Define the `fileSystems` mounts on the host, or set `medinix.hostIntegration.storage = "managed";`.
      '';
    }
    {
      assertion = cfg.vpn.enable -> (config.networking.firewall.checkReversePath != true);
      message = ''
        [mediNix] VPN Killswitch is enabled, but networking.firewall.checkReversePath is true!
        
        [AI/Admin Context]
        Reason: The Wireguard Killswitch uses asymmetric policy routing (fwmark). Strict reverse path filtering (rp_filter=1) will silently drop incoming handshake packets because the return path doesn't match the routing table.
        Ref: ADR-5260 (VPN Killswitch)
        Fix: Set `networking.firewall.checkReversePath = false;` (or use config.medinix.recommended.firewall) in the host configuration.
      '';
    }
    {
      assertion = !config.virtualisation.docker.enable && !config.virtualisation.podman.enable;
      message = ''
        [mediNix] Docker/Podman are enabled on the host!
        
        [AI/Admin Context]
        Reason: mediNix enforces declarative purity. Container engines on the media stack host introduce imperative state and bypass the NixOS systemd hardening profiles.
        Ref: Master Architecture Principles (No Containers)
        Fix: Disable Docker/Podman on this host.
      '';
    }
  ];
}
