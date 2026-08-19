# ---
# id: "590-core-guardrails"
# title: "Core Architecture Guardrails"
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
    # INV-01: Port = ServiceNumber × 10 (Dezimalrahmen SSoT aus lib/registry.nix)
    (reg.mkInvariant "INV-01"
      (let registry = import ../lib/registry.nix { inherit lib; };
       in lib.all (svc: svc.port == null || svc.port == svc.number * 10)
            (lib.attrValues registry.services)))

    # INV-02: Binding — Jellyfin muss explizit auf 127.0.0.1 binden (nie 0.0.0.0)
    (reg.mkInvariant "INV-02"
      (!cfg.jellyfin.enable ||
       (config.systemd.services ? "jellyfin" &&
        config.systemd.services."jellyfin".environment.JELLYFIN_NetworkConfiguration__LocalNetworkAddresses or "" == "127.0.0.1")))

    # INV-03: GID 5000 = media für alle Core-Mediendienste in der Registry
    (reg.mkInvariant "INV-03"
      (let registry = import ../lib/registry.nix { inherit lib; };
           servicesWithGid = lib.filterAttrs (_: svc: svc.gid != null) registry.services;
       in lib.all (svc: svc.gid == 5000) (lib.attrValues servicesWithGid)))

    # INV-UMASK-01: dotnet-Dienste müssen UMask=0002 haben
    (reg.mkInvariant "INV-UMASK-01"
      (let registry = import ../lib/registry.nix { inherit lib; };
           dotnetServices = lib.filterAttrs (_: svc: svc.hardeningProfile == "dotnet" || svc.hardeningProfile == "dotnet-gpu") registry.services;
       in lib.all (svc:
         let 
           unitName = "${svc.unitName}.service";
           isEnabled = cfg.${svc.name}.enable or false;
         in 
           !isEnabled ||
           (config.systemd.services ? ${svc.unitName} &&
            config.systemd.services.${svc.unitName}.serviceConfig.UMask or "" == "0002")
       ) (lib.attrValues dotnetServices)))
  ];
}
