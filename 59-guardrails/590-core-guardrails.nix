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
    # INV-03: GID 5000 = media für alle Core-Mediendienste in der Registry
    (reg.mkInvariant "INV-03"
      (let registry = import ../lib/registry.nix { inherit lib; };
           servicesWithGid = lib.filterAttrs (_: svc: svc.gid != null) registry.services;
       in lib.all (svc: svc.gid == 5000) (lib.attrValues servicesWithGid)))

    # INV-UMASK-01: dotnet-Dienste müssen UMask=0002 haben
    (reg.mkInvariant "INV-UMASK-01"
      (let registry = import ../lib/registry.nix { inherit lib; };
           dotnetServices = lib.mapAttrsToList (_: svc: if svc.port != null then "${svc.name}-${toString svc.port}.service" else "${svc.name}.service")
                              (lib.filterAttrs (_: svc: svc.hardeningProfile == "dotnet" || svc.hardeningProfile == "dotnet-gpu") registry.services);
       in lib.all (svc:
         !(config.systemd.services ? ${svc}) ||
         config.systemd.services.${svc}.serviceConfig.UMask or "" == "0002")
       dotnetServices))
  ];
}
