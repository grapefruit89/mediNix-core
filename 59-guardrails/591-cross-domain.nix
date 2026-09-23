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

  # Decimal-framework invariants over the whole registry (ADR-0000 §4, I1/I2).
  # The folder-name enforcer lives in flake.nix; these check the VALUES.
  portable = lib.filterAttrs (_: svc: svc.port != null) svcReg.services;
  allSvcs = svcReg.services;
  regUids = lib.mapAttrsToList (_: svc: svc.uid) portable;
  dfracViolations = lib.flatten [
    (lib.mapAttrsToList (n: s:
      lib.optional (s.num < 100 || s.num > 999 || !(lib.hasPrefix "5" (toString s.num)))
        "${n}: num ${toString s.num} (I1: 3-stellig, I2: Projektziffer 5)") allSvcs)
    (lib.mapAttrsToList (n: s:
      lib.optional (s.port != s.num * 10 || s.port <= 1023 || s.port >= 65535)
        "${n}: Port ${toString s.port} != num*10 oder ausserhalb (1023, 65535)") portable)
    (lib.mapAttrsToList (n: s:
      lib.optional (s.uid != s.port)
        "${n}: UID ${toString s.uid} != Port ${toString s.port}") portable)
    (lib.mapAttrsToList (n: s:
      lib.optional (s.gid != 5000)
        "${n}: GID ${toString s.gid} != 5000 (projektweit geteilt)") allSvcs)
    (lib.optional (lib.length regUids != lib.length (lib.unique regUids))
      "doppelte UID im Registry")
  ];

  # Factory output check (ADR-5050): factory-created services (stateDir registered
  # in knownStateDirs) must yield User=<name>, Group=media, StateDirectory, and a
  # system user with the registry uid.
  factoryCreated = s: s.stateDir != null && lib.elem s.stateDir (config.medinix.knownStateDirs or [ ]);
  svcCfgOf = n: config.systemd.services.${n}.serviceConfig or { };
  factoryViolations = lib.flatten (lib.mapAttrsToList (n: s:
    lib.optionals (factoryCreated s) [
      (lib.optional ((svcCfgOf n).User or null != n) "${n}: unit User != ${n}")
      (lib.optional ((svcCfgOf n).Group or null != "media") "${n}: unit Group != media")
      (lib.optional (!((svcCfgOf n) ? StateDirectory)) "${n}: unit StateDirectory missing")
      (lib.optional ((config.users.users.${n}.uid or null) != s.uid) "${n}: user uid != registry ${toString s.uid}")
      (lib.optional ((config.users.users.${n}.group or null) != "media") "${n}: user group != media")
    ]) allSvcs);
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
      assertion = !confined "prowlarr";
      message = ''
        [mediNix] Prowlarr must NEVER be confined under vpnKillSwitch (it requires direct WAN access for indexers).
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
    {
      assertion = dfracViolations == [ ];
      message = ''
        [mediNix] Dezimalrahmen (ADR-0000 §4) verletzt:
        ${lib.concatStringsSep "\n        " dfracViolations}
      '';
    }
    {
      assertion = factoryViolations == [ ];
      message = ''
        [mediNix] Service-Factory (ADR-5050) verletzt:
        ${lib.concatStringsSep "\n        " factoryViolations}
      '';
    }
  ];
}
