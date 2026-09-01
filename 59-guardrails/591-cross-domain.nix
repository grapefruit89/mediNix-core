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
{ config, lib, ... }:

let
  cfg = config.medinix;
  svcReg = import ../lib/registry.nix { inherit lib; };
  ks = config.services.vpnKillSwitch or { instances = { }; };
  confined = name:
    (builtins.hasAttr name ks.instances) && ks.instances.${name}.enable;

  enabledPorts = lib.mapAttrsToList (_: svc: svc.port) (
    lib.filterAttrs
      (n: svc: svc.port != null && (cfg.${n}.enable or false))
      svcReg.services
  );
  allowedTCP = config.networking.firewall.allowedTCPPorts or [ ];
  leakingPorts = lib.filter (p: lib.elem p allowedTCP) enabledPorts;

  hasFs = path: builtins.hasAttr path (config.fileSystems or { });

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
        SABnzbd would leave via WAN.
        Option path: medinix.usenet-confinement.enable (not security.usenet-confinement).
      '';
    }
    {
      assertion = (cfg.usenet-confinement.enable && cfg.prowlarr.enable) -> confined "prowlarr";
      message = ''
        [mediNix] usenet-confinement and Prowlarr are on, but vpnKillSwitch.instances.prowlarr is off.
      '';
    }
    {
      assertion = leakingPorts == [ ];
      message = ''
        [mediNix] service ports in networking.firewall.allowedTCPPorts: ${toString leakingPorts}
        Units bind 127.0.0.1. Publish only through 511.
      '';
    }
    {
      assertion = !wantsHostCaddy || config.services.caddy.enable;
      message = ''
        [mediNix] reverseProxy = "external" and ingress.mode != "standalone",
        but services.caddy.enable is false.
        External = host Caddy. managed / standalone = 511 caddy-media.
      '';
    }
    {
      assertion = !wantsNft || config.networking.nftables.enable;
      message = ''
        [mediNix] VPN/usenet confinement needs nftables; hostIntegration.nftables = "external"
        and networking.nftables.enable is false.
      '';
    }
    {
      assertion =
        !(cfg.hostIntegration.storage == "external"
          && cfg.storage.backends ? hot
          && cfg.storage.backends ? cold)
        || (hasFs cfg.storage.backends.hot && hasFs cfg.storage.backends.cold);
      message = ''
        [mediNix] external storage with hot+cold backends, but fileSystems is missing those paths.
      '';
    }
    {
      assertion = !cfg.vpn.enable || (config.networking.firewall.checkReversePath != true);
      message = ''
        [mediNix] vpn.enable needs networking.firewall.checkReversePath != true.
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
