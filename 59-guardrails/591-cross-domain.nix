# ---
# id: "591-cross-domain"
# title: "Fail-closed assertions across domains"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 3
# last_reviewed: 2026-09-02
# links:
# provides: ["guardrails"]
# requires: ["lib/registry", "526-vpn-killswitch", "511-caddy"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# adr: ADR-5043
# ---
# Single guardrail organ. Former 592-environment.nix folded in.
# Assertions only — no units, no sysctl writes.
{ config, lib, ... }:

let
  cfg = config.medinix;
  svcReg = import ../lib/registry.nix { inherit lib; };
  ks = config.services.vpnKillSwitch or { instances = { }; };
  confined = name:
    (ks.instances ? ${name}) && ks.instances.${name}.enable;

  enabledPorts = lib.mapAttrsToList (_: svc: svc.port) (
    lib.filterAttrs
      (_: svc: svc.port != null && (cfg.${svc.name}.enable or false))
      svcReg.services
  );
  allowedTCP = config.networking.firewall.allowedTCPPorts or [ ];
  leakingPorts = lib.filter (p: lib.elem p allowedTCP) enabledPorts;

  hasFs = path: builtins.hasAttr path (config.fileSystems or { });

  # 511 chameleon: global Caddy is only required when the host said so.
  wantsHostCaddy =
    cfg.ingress.enable
    && cfg.hostIntegration.reverseProxy == "external"
    && cfg.ingress.mode != "standalone";

  wantsNft =
    cfg.hostIntegration.nftables == "external"
    && (cfg.vpn.enable || cfg.usenet-confinement.enable);
in
lib.mkIf cfg.enable {
  assertions = [
    {
      assertion = cfg.usenet-confinement.enable -> confined "sabnzbd";
      message = ''
        [mediNix] usenet-confinement.enable is set, but vpnKillSwitch.instances.sabnzbd is not active.
        SABnzbd would leave via WAN. Wire the unit in 541 / killswitch instances, or disable usenet-confinement.
        Option path: medinix.usenet-confinement.enable (not security.usenet-confinement).
      '';
    }
    {
      assertion = (cfg.usenet-confinement.enable && cfg.prowlarr.enable) -> confined "prowlarr";
      message = ''
        [mediNix] usenet-confinement and Prowlarr are on, but vpnKillSwitch.instances.prowlarr is off.
        Indexer traffic would leak beside confined SABnzbd.
      '';
    }
    {
      assertion = leakingPorts == [ ];
      message = ''
        [mediNix] service ports in networking.firewall.allowedTCPPorts: ${toString leakingPorts}
        Units bind 127.0.0.1. Publish only through 511 (80/443), not the app ports.
      '';
    }
    {
      assertion = !wantsHostCaddy || config.services.caddy.enable;
      message = ''
        [mediNix] hostIntegration.reverseProxy = "external" and ingress.mode is not standalone,
        but services.caddy.enable is false.
        External = the host daemon. Managed / ingress.mode = "standalone" = 511 caddy-media.
        Fix: services.caddy.enable = true, or reverseProxy = "managed", or ingress.mode = "standalone".
      '';
    }
    {
      assertion = !wantsNft || config.networking.nftables.enable;
      message = ''
        [mediNix] VPN/usenet confinement needs nftables; hostIntegration.nftables = "external"
        and networking.nftables.enable is false.
        Enable nftables on the host or set hostIntegration.nftables = "managed".
      '';
    }
    {
      assertion =
        !(cfg.hostIntegration.storage == "external"
          && cfg.storage.backends ? hot
          && cfg.storage.backends ? cold)
        || (hasFs cfg.storage.backends.hot && hasFs cfg.storage.backends.cold);
      message = ''
        [mediNix] storage is external with hot+cold backends, but fileSystems is missing
        ${cfg.storage.backends.hot or "<hot>"} and/or ${cfg.storage.backends.cold or "<cold>"}.
        Host mounts those paths, or set hostIntegration.storage = "managed".
      '';
    }
    {
      assertion = !cfg.vpn.enable || (config.networking.firewall.checkReversePath != true);
      message = ''
        [mediNix] vpn.enable needs networking.firewall.checkReversePath != true (false or "loose").
        Strict rp_filter drops WireGuard handshake on marked flows.
      '';
    }
    {
      assertion = !(config.virtualisation.docker.enable or false)
        && !(config.virtualisation.podman.enable or false);
      message = ''
        [mediNix] Docker/Podman are enabled. This stack is systemd-only.
      '';
    }
  ];
}
