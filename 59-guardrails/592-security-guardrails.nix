# ---
# id: "592-security-guardrails"
# title: "Security & Hardening Guardrails"
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
    (reg.mkErrorDoc "SEC-001" !(cfg.observability.crowdsec.enable && cfg.observability.crowdsec.enrollKeyFile == null) "5820")
    
    # INV-SECRET: Kein Secret-Pfad im Nix-Store
    (reg.mkInvariant "INV-SECRET"
      (let sopsSecrets = lib.attrValues config.sops.secrets;
       in lib.all (s: !(lib.hasPrefix "/nix/store" s.path)) sopsSecrets))

    # INV-TECH-01..03: Verbotene Technologien strukturell unmöglich machen
    (reg.mkInvariant "INV-TECH-01" (!config.virtualisation.docker.enable))
    (reg.mkInvariant "INV-TECH-02" (!config.virtualisation.podman.enable))
    (reg.mkInvariant "INV-TECH-03" (!config.services.cron.enable))

    # INV-FW-01: NFTables Firewall muss aktiv sein (für VPN UID Kill-Switch)
    (reg.mkInvariant "INV-FW-01" (config.networking.nftables.enable))
  ];

  # Security-Enforcement: Emergency User (früher 593)
  users.groups.media.gid = 5000;
  security.sudo.extraConfig =
    let
      registry = import ../lib/registry.nix { inherit lib; };
      restartCmds = lib.mapAttrsToList
        (_: svc: "/run/current-system/sw/bin/systemctl restart ${if svc.port != null then "${svc.name}-${toString svc.port}" else svc.name}.service")
        registry.services;
      cmdString = lib.concatStringsSep ", \\\n                                           " restartCmds;
    in ''
      %media-admin ALL=(root) NOPASSWD: ${cmdString}
      %media-admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl status *
    '';

  # Security-Enforcement: No-Password Auth (früher 594)
  security.sudo.wheelNeedsPassword = false;
}
