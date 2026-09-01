# ---
# id: "591-cross-domain"
# title: "Fail-closed assertions across domains"
# domain: 59
# folder: 59-guardrails
# status: active
# last_reviewed: 2026-09-02
# provides: ["guardrails"]
# requires: ["lib/registry", "526-vpn-killswitch", "511-caddy"]
# adr: ADR-5043
# ---
{ config, lib, ... }:

let
  cfg = config.medinix;
  svcReg = import ../lib/registry.nix { inherit lib; };
  ks = config.services.vpnKillSwitch or { instances = { }; };
  confined = name:
    (builtins.hasAttr name ks.instances) && ks.instances.${name}.enable;

  enabledOf = n:
    if n == "pocket-id" then cfg.pocketId.enable or false
    else cfg.${n}.enable or false;

  enabledPortable = lib.filterAttrs
    (n: svc: svc.port != null && enabledOf n)
    svcReg.services;

  enabledPorts = lib.mapAttrsToList (_: svc: svc.port) enabledPortable;
  allowedTCP = config.networking.firewall.allowedTCPPorts or [ ];
  leakingPorts = lib.filter (p: lib.elem p allowedTCP) enabledPorts;

  envVals = unit:
    lib.attrValues ((config.systemd.services.${unit}.environment or {}));

  isWildcardBind = v:
    v == "0.0.0.0" || v == "*" || v == "[::]" || v == "::";

  wildcardBinds = lib.attrNames (lib.filterAttrs (n: svc:
    lib.any isWildcardBind (envVals svc.unitName)
  ) enabledPortable);

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
        Option path: medinix.usenet-confinement.enable.
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
        Publish only through 511.
      '';
    }
    {
      assertion = wildcardBinds == [ ];
      message = ''
        [mediNix] unit environment binds 0.0.0.0/* for: ${lib.concatStringsSep ", " wildcardBinds}
        Writers stay on 127.0.0.1. 511 is the only published socket.
      '';
    }
    {
      assertion = !wantsHostCaddy || config.services.caddy.enable;
      message = ''
        [mediNix] reverseProxy = "external" and ingress.mode != "standalone",
        but services.caddy.enable is false.
      '';
    }
    {
      assertion = !wantsNft || config.networking.nftables.enable;
      message = ''
        [mediNix] VPN/usenet needs nftables; hostIntegration.nftables = "external"
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
      message = "[mediNix] vpn.enable needs networking.firewall.checkReversePath != true.";
    }
    {
      assertion = !(config.virtualisation.docker.enable or false)
        && !(config.virtualisation.podman.enable or false);
      message = "[mediNix] Docker/Podman are enabled. This stack is systemd-only.";
    }
  ];
}
